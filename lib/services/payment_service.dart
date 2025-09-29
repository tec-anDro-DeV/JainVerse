import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:jainverse/Presenter/PlanPresenter.dart';
import 'package:jainverse/UI/HomeDiscover.dart';
import 'package:jainverse/UI/PaymentSuccess.dart';
import 'package:jainverse/paymentgateway/Stripe.dart';
import 'package:jainverse/utils/SharedPref.dart';

/// Unified Payment Service for handling platform-specific payments
/// iOS: Apple In-App Purchase (Sandbox/Test Mode)
/// Android: Stripe Payment (Test Mode)
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  // In-App Purchase instance
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // State management
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  Map<String, ProductDetails> _productMap = {};
  bool _purchaseInProgress = false;
  bool _isInitializing = false; // Flag to track initialization state

  // Track processed purchases to prevent duplicate API calls
  final Set<String> _processedPurchaseIds = {};
  final Set<String> _globalProcessedPurchaseIds =
      {}; // Never cleared, prevents all duplicates
  final Completer<void> _initializationCompleter = Completer<void>();
  bool _isInitialized = false;

  // User data
  final SharedPref _sharePrefs = SharedPref();
  String _userEmail = '';
  String _userName = '';
  String _token = '';

  // Callbacks
  Function(String planId, String paymentId, String amount)? _onSuccess;
  Function(String error)? _onError;

  // Navigation context for Apple IAP success
  BuildContext? _currentContext;

  /// Product IDs mapping for iOS In-App Purchase
  /// These MUST match the product IDs created in App Store Connect
  // Product mapping (plan string id -> App Store product id)
  // This mapping can be populated at runtime from backend plan data.
  static Map<String, String> _iOSProductIds = {};

  // Reverse mapping for efficiency (product id -> plan id)
  static Map<String, String> _reverseProductIds = {};

  void setIOSProductMapping(Map<String, String> mapping) {
    _iOSProductIds = Map.from(mapping);
    _reverseProductIds = {
      for (var entry in _iOSProductIds.entries) entry.value: entry.key,
    };
  }

  /// Initialize the payment service
  Future<void> initialize() async {
    if (_isInitialized) {
      return _initializationCompleter.future;
    }

    developer.log('[PaymentService] Initializing...', name: 'PaymentService');

    try {
      // Load user data
      await _loadUserData();

      if (Platform.isIOS) {
        await _initializeAppleInAppPurchase();
      }
      // Android will use existing Stripe implementation

      _isInitialized = true;
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }

      developer.log(
        '[PaymentService] Initialized successfully',
        name: 'PaymentService',
      );
    } catch (e) {
      developer.log(
        '[PaymentService] Initialization failed: $e',
        name: 'PaymentService',
        error: e,
      );
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.completeError(e);
      }
      rethrow;
    }
  }

  /// Initialize Apple In-App Purchase for iOS
  Future<void> _initializeAppleInAppPurchase() async {
    developer.log(
      '[PaymentService] Initializing Apple In-App Purchase...',
      name: 'PaymentService',
    );

    _isInitializing = true; // Set initialization flag

    // Check if in-app purchase is available
    _isAvailable = await _inAppPurchase.isAvailable();

    if (!_isAvailable) {
      developer.log(
        '[PaymentService] In-App Purchase not available',
        name: 'PaymentService',
      );
      _isInitializing = false;
      return;
    }

    // Load products
    await _loadProducts();

    // Set up purchase stream listener but don't process old transactions
    _subscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdate,
      onError:
          (error) => developer.log(
            '[PaymentService] Purchase stream error: $error',
            name: 'PaymentService',
          ),
      cancelOnError: false,
    );

    _isInitializing = false; // Clear initialization flag

    developer.log(
      '[PaymentService] Apple In-App Purchase initialized successfully',
      name: 'PaymentService',
    );
  }

  /// Load available products from App Store
  Future<void> _loadProducts() async {
    developer.log(
      '[PaymentService] Loading products...',
      name: 'PaymentService',
    );

    final Set<String> productIds = _iOSProductIds.values.toSet();
    final ProductDetailsResponse response = await _inAppPurchase
        .queryProductDetails(productIds);

    if (response.notFoundIDs.isNotEmpty) {
      developer.log(
        '[PaymentService] Products not found: ${response.notFoundIDs}',
        name: 'PaymentService',
      );
    }

    _products = response.productDetails;
    _productMap = {for (var product in _products) product.id: product};

    developer.log(
      '[PaymentService] Loaded ${_products.length} products',
      name: 'PaymentService',
    );
    for (var product in _products) {
      developer.log(
        '[PaymentService] Product: ${product.id} - ${product.title} - ${product.price}',
        name: 'PaymentService',
      );
    }
  }

  /// Load user data from SharedPreferences
  Future<void> _loadUserData() async {
    try {
      final user = await _sharePrefs.getUserData();
      _userEmail = user.data.email;
      _userName = user.data.name;
      _token = await _sharePrefs.getToken();

      developer.log(
        '[PaymentService] User data loaded - Email: $_userEmail, Name: $_userName',
        name: 'PaymentService',
      );
    } catch (e) {
      developer.log(
        '[PaymentService] Failed to load user data: $e',
        name: 'PaymentService',
        error: e,
      );
    }
  }

  /// Start purchase process - routes to appropriate platform
  Future<void> startPurchase({
    required String productId,
    required String planName,
    required String amount,
    required BuildContext context,
    Function(String planId, String paymentId, String amount)? onSuccess,
    Function(String error)? onError,
  }) async {
    developer.log(
      '[PaymentService] Starting purchase for product: $productId',
      name: 'PaymentService',
    );

    // Ensure initialization is complete
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        onError?.call('Failed to initialize payment service: $e');
        return;
      }
    }

    if (_purchaseInProgress) {
      developer.log(
        '[PaymentService] Purchase already in progress',
        name: 'PaymentService',
      );
      onError?.call('Purchase already in progress');
      return;
    }

    // Set callbacks and context
    _onSuccess = onSuccess;
    _onError = onError;
    _currentContext = context;

    // Only clear session-specific processed purchases, not global ones
    _processedPurchaseIds.clear();

    try {
      if (Platform.isIOS) {
        await _startAppleInAppPurchase(productId, planName, amount, context);
      } else if (Platform.isAndroid) {
        await _startStripePayment(productId, planName, amount, context);
      } else {
        throw Exception('Unsupported platform');
      }
    } catch (e) {
      developer.log(
        '[PaymentService] Purchase failed: $e',
        name: 'PaymentService',
        error: e,
      );
      _purchaseInProgress = false;
      onError?.call(e.toString());
    }
  }

  /// Start Apple In-App Purchase (iOS)
  Future<void> _startAppleInAppPurchase(
    String productId,
    String planName,
    String amount,
    BuildContext context,
  ) async {
    developer.log(
      '[PaymentService] Starting Apple In-App Purchase for: $productId',
      name: 'PaymentService',
    );

    if (!_isAvailable) {
      throw Exception('In-App Purchase not available');
    }

    // productId can be either a logical plan id (eg 'family_monthly') or an App Store product id.
    String? iOSProductId = _iOSProductIds[productId];
    // If mapping not found, maybe productId already is the App Store id
    iOSProductId ??= productId;

    // Get product details
    final ProductDetails? productDetails = _productMap[iOSProductId];
    if (productDetails == null) {
      throw Exception('Product not found: $iOSProductId');
    }

    _purchaseInProgress = true;

    // Create purchase param
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: productDetails,
      applicationUserName: _userEmail, // Used for server-side verification
    );

    developer.log(
      '[PaymentService] Initiating purchase for: ${productDetails.title}',
      name: 'PaymentService',
    );

    // Start the purchase - this triggers the purchase flow
    try {
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      // Note: Success/failure is handled in the purchase stream listener
    } catch (e) {
      _purchaseInProgress = false;
      rethrow;
    }
  }

  /// Start Stripe Payment (Android)
  Future<void> _startStripePayment(
    String productId,
    String planName,
    String amount,
    BuildContext context,
  ) async {
    developer.log(
      '[PaymentService] Starting Stripe payment for Android',
      name: 'PaymentService',
    );

    // Use existing Stripe implementation
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => StripePay(
              planName,
              amount,
              productId,
              '', // coupon id
              '', // discount
              amount, // exact amount
              _userEmail,
              _userName,
            ),
      ),
    );
  }

  /// Handle purchase updates from Apple
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    developer.log(
      '[PaymentService] Received ${purchaseDetailsList.length} purchase updates',
      name: 'PaymentService',
    );

    for (PurchaseDetails purchase in purchaseDetailsList) {
      await _handlePurchase(purchase);
    }
  }

  /// Handle individual purchase with improved duplicate prevention
  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    final String purchaseId = purchaseDetails.purchaseID ?? '';
    final String transactionId = purchaseDetails.transactionDate ?? '';

    // Create a more robust lock key using multiple identifiers
    final String lockKey =
        purchaseId.isNotEmpty
            ? purchaseId
            : '${purchaseDetails.productID}_${transactionId}_${DateTime.now().millisecondsSinceEpoch}';

    developer.log(
      '[PaymentService] Handling purchase: ${purchaseDetails.productID} - Status: ${purchaseDetails.status} - ID: $purchaseId - LockKey: $lockKey - PurchaseInProgress: $_purchaseInProgress - TransactionDate: ${purchaseDetails.transactionDate}',
      name: 'PaymentService',
    );

    // Enhanced duplicate prevention - check both session and global processed lists
    if (_processedPurchaseIds.contains(lockKey) ||
        _globalProcessedPurchaseIds.contains(lockKey)) {
      developer.log(
        '[PaymentService] Skipping already processed purchase: $lockKey',
        name: 'PaymentService',
      );

      // Still complete the purchase if needed
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
      return;
    }

    // CRITICAL FIX: Only process purchases when we are in an active purchase flow
    // This prevents old/existing transactions from being processed when the app starts
    if (!_purchaseInProgress && !_isInitializing) {
      developer.log(
        '[PaymentService] Skipping purchase update - no active purchase flow and not initializing. This is likely an old transaction.',
        name: 'PaymentService',
      );

      // Still complete the purchase if needed to prevent it from being reported again
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
      return;
    }

    // During initialization, skip any transactions older than 2 minutes to avoid processing old ones
    if (_isInitializing && purchaseDetails.transactionDate != null) {
      try {
        final transactionDateTime = DateTime.fromMillisecondsSinceEpoch(
          int.parse(purchaseDetails.transactionDate!),
        );
        final now = DateTime.now();
        final timeDifference = now.difference(transactionDateTime);

        // If transaction is older than 2 minutes during initialization, skip it
        if (timeDifference.inMinutes > 2) {
          developer.log(
            '[PaymentService] Skipping old transaction during initialization from ${transactionDateTime.toIso8601String()}',
            name: 'PaymentService',
          );

          // Complete old purchases to prevent them from being reported again
          if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
          return;
        }
      } catch (e) {
        developer.log(
          '[PaymentService] Error parsing transaction date during initialization: $e',
          name: 'PaymentService',
        );
      }
    }

    // Additional check: Only process very recent transactions (within last 5 minutes)
    // to avoid processing old transactions that might be reported by iOS
    if (purchaseDetails.transactionDate != null) {
      try {
        final transactionDateTime = DateTime.fromMillisecondsSinceEpoch(
          int.parse(purchaseDetails.transactionDate!),
        );
        final now = DateTime.now();
        final timeDifference = now.difference(transactionDateTime);

        // If transaction is older than 5 minutes, skip it unless we're in active purchase flow
        if (timeDifference.inMinutes > 5) {
          developer.log(
            '[PaymentService] Skipping old transaction from ${transactionDateTime.toIso8601String()}',
            name: 'PaymentService',
          );

          // Complete old purchases to prevent them from being reported again
          if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
          return;
        }
      } catch (e) {
        developer.log(
          '[PaymentService] Error parsing transaction date: $e',
          name: 'PaymentService',
        );
      }
    }

    try {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Mark as processed immediately in both sets to prevent duplicates
        _processedPurchaseIds.add(lockKey);
        _globalProcessedPurchaseIds.add(lockKey);

        // Only process purchases when in active purchase flow
        if (_purchaseInProgress) {
          // Purchase successful
          await _completePurchase(purchaseDetails);
        } else {
          developer.log(
            '[PaymentService] Purchase already completed or not in active flow',
            name: 'PaymentService',
          );
        }
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // Purchase failed
        developer.log(
          '[PaymentService] Purchase failed: ${purchaseDetails.error}',
          name: 'PaymentService',
        );
        _purchaseInProgress = false;
        _onError?.call(purchaseDetails.error?.message ?? 'Purchase failed');
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        // Purchase canceled
        developer.log(
          '[PaymentService] Purchase canceled',
          name: 'PaymentService',
        );
        _purchaseInProgress = false;
        _onError?.call('Purchase canceled');
      } else if (purchaseDetails.status == PurchaseStatus.pending) {
        // Purchase pending (e.g., parental approval required)
        developer.log(
          '[PaymentService] Purchase pending',
          name: 'PaymentService',
        );
        // Don't change _purchaseInProgress state, wait for final result
      }

      // Complete the purchase (mark as consumed)
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    } catch (e) {
      developer.log(
        '[PaymentService] Error handling purchase: $e',
        name: 'PaymentService',
        error: e,
      );
      _purchaseInProgress = false;
      _onError?.call(e.toString());
    }
  }

  /// Complete successful purchase
  Future<void> _completePurchase(PurchaseDetails purchaseDetails) async {
    final String purchaseId = purchaseDetails.purchaseID ?? '';

    developer.log(
      '[PaymentService] Completing purchase: ${purchaseDetails.productID} (ID: $purchaseId)',
      name: 'PaymentService',
    );

    // Additional safety check: Only process if we're actually in a purchase flow
    if (!_purchaseInProgress) {
      developer.log(
        '[PaymentService] Ignoring completion - not in active purchase flow',
        name: 'PaymentService',
      );
      return;
    }

    // Create a unique transaction key to prevent duplicate processing
    final String transactionKey =
        purchaseId.isNotEmpty
            ? 'txn_$purchaseId'
            : 'txn_${purchaseDetails.productID}_${DateTime.now().millisecondsSinceEpoch}';

    // Check if this specific transaction was already processed
    if (_globalProcessedPurchaseIds.contains(transactionKey)) {
      developer.log(
        '[PaymentService] Transaction already processed: $transactionKey',
        name: 'PaymentService',
      );
      return;
    }

    // Mark transaction as being processed
    _globalProcessedPurchaseIds.add(transactionKey);

    try {
      // Get the original product ID using reverse mapping
      final String? originalProductId =
          _reverseProductIds[purchaseDetails.productID];

      if (originalProductId == null) {
        throw Exception(
          'Original product ID not found for: ${purchaseDetails.productID}',
        );
      }

      // Get product details for amount
      final ProductDetails? productDetails =
          _productMap[purchaseDetails.productID];
      final String amount = productDetails?.rawPrice.toString() ?? '0';

      // Create payment data for backend
      final String paymentData = _createPaymentData(
        orderId:
            purchaseId.isNotEmpty
                ? purchaseId
                : DateTime.now().millisecondsSinceEpoch.toString(),
        planId: originalProductId,
        amount: amount,
        paymentId: purchaseId,
        transactionId: purchaseId,
        currency: productDetails?.currencyCode ?? 'USD',
      );

      // Save to backend
      await _savePurchaseToBackend(
        paymentType: 'apple_iap',
        planId: originalProductId,
        paymentData: paymentData,
        orderId:
            purchaseId.isNotEmpty
                ? purchaseId
                : DateTime.now().millisecondsSinceEpoch.toString(),
      );

      _purchaseInProgress = false;

      // For Apple IAP, navigate directly to success screen since payment is already processed
      if (_currentContext != null && _currentContext!.mounted) {
        navigateToSuccessDirectly(
          _currentContext!,
          paymentType: 'apple_iap',
          planId: originalProductId,
          paymentId: purchaseId,
          orderId:
              purchaseId.isNotEmpty
                  ? purchaseId
                  : DateTime.now().millisecondsSinceEpoch.toString(),
          amount: amount,
        );
      }

      // Call success callback with a flag to indicate processing is complete
      _onSuccess?.call(originalProductId, purchaseId, amount);

      developer.log(
        '[PaymentService] Purchase completed successfully',
        name: 'PaymentService',
      );
    } catch (e) {
      developer.log(
        '[PaymentService] Error completing purchase: $e',
        name: 'PaymentService',
        error: e,
      );
      _purchaseInProgress = false;
      _onError?.call(e.toString());
    }
  }

  /// Create payment data JSON for backend
  String _createPaymentData({
    required String orderId,
    required String planId,
    required String amount,
    required String paymentId,
    required String transactionId,
    required String currency,
  }) {
    // Get numeric plan ID from string ID
    int numericPlanId = PlanPresenter().getNumericPlanId(planId);

    return '[{"order_id":"$orderId","plan_id":$numericPlanId,"amount":"$amount","currency":"$currency","discount":"","taxAmount":"","payment_gateway":"apple_iap","user_email":"$_userEmail","user_name":"$_userName","taxPercent":"","plan_exact_amount":"$amount","payment_id":"$paymentId","coupon_id":"","transaction_id":"$transactionId"}]';
  }

  /// Save purchase to backend
  Future<void> _savePurchaseToBackend({
    required String paymentType,
    required String planId,
    required String paymentData,
    required String orderId,
  }) async {
    developer.log(
      '[PaymentService] Saving purchase to backend...',
      name: 'PaymentService',
    );

    try {
      await PlanPresenter().savePlan(
        paymentType,
        planId,
        paymentData,
        orderId,
        _token,
        _currentContext!,
      );

      developer.log(
        '[PaymentService] Purchase saved to backend successfully',
        name: 'PaymentService',
      );
    } catch (e) {
      developer.log(
        '[PaymentService] Failed to save purchase to backend: $e',
        name: 'PaymentService',
        error: e,
      );
      rethrow;
    }
  }

  /// Navigate to success screen directly (for Apple IAP)
  void navigateToSuccessDirectly(
    BuildContext context, {
    required String paymentType,
    required String planId,
    required String paymentId,
    required String orderId,
    required String amount,
  }) {
    // For Apple IAP, the payment was already processed during the purchase flow
    // So we pass an empty paymentData to avoid duplicate API calls
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (context) => PaymentSuccess(
              paymentType,
              planId,
              paymentId,
              orderId,
              amount,
              '', // Empty paymentData to skip API call
            ),
      ),
    );
  }

  /// Navigate to success screen
  void navigateToSuccess(
    BuildContext context, {
    required String paymentType,
    required String planId,
    required String paymentId,
    required String orderId,
    required String amount,
    required String paymentData,
  }) {
    // For Apple IAP, the payment was already processed during the purchase flow
    // So we pass an empty paymentData to avoid duplicate API calls
    final String finalPaymentData =
        paymentType == 'apple_iap' ? '' : paymentData;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (context) => PaymentSuccess(
              paymentType,
              planId,
              paymentId,
              orderId,
              amount,
              finalPaymentData,
            ),
      ),
    );
  }

  /// Navigate to home screen
  void navigateToHome(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeDiscover()),
    );
  }

  /// Restore purchases (iOS only)
  Future<void> restorePurchases() async {
    if (!Platform.isIOS || !_isAvailable) {
      developer.log(
        '[PaymentService] Restore not available on this platform',
        name: 'PaymentService',
      );
      return;
    }

    developer.log(
      '[PaymentService] Restoring purchases...',
      name: 'PaymentService',
    );

    try {
      await _inAppPurchase.restorePurchases();
      developer.log(
        '[PaymentService] Restore purchases initiated',
        name: 'PaymentService',
      );
    } catch (e) {
      developer.log(
        '[PaymentService] Restore purchases failed: $e',
        name: 'PaymentService',
        error: e,
      );
    }
  }

  /// Check if a product is available
  bool isProductAvailable(String productId) {
    if (Platform.isAndroid) return true; // Stripe handles this

    final iOSProductId = _iOSProductIds[productId] ?? productId;
    return _productMap.containsKey(iOSProductId);
  }

  /// Get product price for display
  String getProductPrice(String productId) {
    if (Platform.isAndroid) {
      // Return default prices for Android (Stripe)
      final prices = {
        'standard_monthly': '\$9.99',
        'family_monthly': '\$15.99',
        'student_monthly': '\$7.99',
        'standard_yearly': '\$119.88',
        'family_yearly': '\$191.88',
        'student_yearly': '\$95.88',
      };
      return prices[productId] ?? '\$0.00';
    }

    final iOSProductId = _iOSProductIds[productId] ?? productId;
    if (_productMap.containsKey(iOSProductId)) {
      return _productMap[iOSProductId]!.price;
    }
    return '\$0.00';
  }

  /// Get current platform
  String get currentPlatform =>
      Platform.isIOS
          ? 'iOS'
          : Platform.isAndroid
          ? 'Android'
          : 'Unknown';

  /// Check if in test mode
  bool get isTestMode => true; // Always in test mode as requested

  /// Reset the payment service state
  void reset() {
    _purchaseInProgress = false;
    _isInitializing = false;
    _processedPurchaseIds.clear();
    // Note: _globalProcessedPurchaseIds is intentionally NOT cleared to prevent duplicates across app sessions
    _onSuccess = null;
    _onError = null;
    _currentContext = null;
    developer.log('[PaymentService] State reset', name: 'PaymentService');
  }

  /// Dispose resources
  void dispose() {
    reset();
    _subscription?.cancel();
    _subscription = null;
    developer.log('[PaymentService] Disposed', name: 'PaymentService');
  }
}
