import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:jainverse/Model/ModelPlanList.dart';
import 'package:jainverse/Model/ModelSettings.dart';
import 'package:jainverse/Presenter/PlanPresenter.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Controller for managing payment and subscription related functionality
class PaymentController extends ChangeNotifier {
  // Singleton pattern
  static final PaymentController _instance = PaymentController._internal();
  factory PaymentController() => _instance;
  PaymentController._internal();

  final SharedPref _sharePrefs = SharedPref();

  // State variables
  String _token = '';
  String _userId = '';
  String _userEmail = '';
  String _userName = '';

  // Settings
  late ModelSettings _modelSettings;
  bool _allowDownload = false;
  bool _allowAds = true;
  String _currencySym = '\$';

  // Plans
  List<SubData> _plans = [];
  bool _plansLoading = false;

  // Payment gateways
  bool _isRazorpayEnabled = false;
  bool _isStripeEnabled = false;
  bool _isPaystackEnabled = false;

  // Ads
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  bool _isLoadingAd = false;

  // Getters
  List<SubData> get plans => List.unmodifiable(_plans);
  bool get plansLoading => _plansLoading;
  bool get allowDownload => _allowDownload;
  bool get allowAds => _allowAds;
  String get currencySym => _currencySym;
  bool get isRazorpayEnabled => _isRazorpayEnabled;
  bool get isStripeEnabled => _isStripeEnabled;
  bool get isPaystackEnabled => _isPaystackEnabled;
  String get userId => _userId;
  String get userEmail => _userEmail;
  String get userName => _userName;
  bool get isInterstitialAdReady => _isInterstitialAdReady;

  /// Initialize the payment controller
  Future<void> initialize() async {
    await _loadUserData();
    await _loadSettings();
    developer.log(
      '[DEBUG][PaymentController][initialize] Initialized',
      name: 'PaymentController',
    );
  }

  /// Load user data
  Future<void> _loadUserData() async {
    try {
      _token = await _sharePrefs.getToken();
      final model = await _sharePrefs.getUserData();
      _userId = model.data.id.toString();
      _userEmail = model.data.email;
      _userName = model.data.name;
    } catch (e) {
      developer.log(
        '[ERROR][PaymentController][_loadUserData] Failed: $e',
        name: 'PaymentController',
        error: e,
      );
    }
  }

  /// Load app settings
  Future<void> _loadSettings() async {
    try {
      String? sett = await _sharePrefs.getSettings();
      if (sett != null) {
        final Map<String, dynamic> parsed = json.decode(sett);
        _modelSettings = ModelSettings.fromJson(parsed);

        _allowDownload = _modelSettings.data.download == 1;
        _allowAds = _modelSettings.data.ads == 1;

        // Set currency symbol
        if (_modelSettings.data.currencySymbol.isNotEmpty) {
          _currencySym = _modelSettings.data.currencySymbol;
        }

        // Check payment gateway availability
        _isRazorpayEnabled =
            _modelSettings.payment_gateways.razorpay.razorpay_key.isNotEmpty;
        _isStripeEnabled =
            _modelSettings.payment_gateways.stripe.stripe_client_id.isNotEmpty;
        _isPaystackEnabled =
            _modelSettings
                .payment_gateways
                .paystack
                .paystack_public_key
                .isNotEmpty;

        notifyListeners();

        developer.log(
          '[DEBUG][PaymentController][_loadSettings] Settings loaded - Download: $_allowDownload, Ads: $_allowAds',
          name: 'PaymentController',
        );
      }
    } catch (e) {
      developer.log(
        '[ERROR][PaymentController][_loadSettings] Failed: $e',
        name: 'PaymentController',
        error: e,
      );
    }
  }

  /// Load available plans
  Future<void> loadPlans() async {
    if (_token.isEmpty) return;

    _plansLoading = true;
    notifyListeners();

    try {
      String response = await PlanPresenter().getAllPlansLegacy(_token);
      final Map<String, dynamic> parsed = json.decode(response.toString());
      ModelPlanList mList = ModelPlanList.fromJson(parsed);
      _plans = mList.data.first.all_plans;

      developer.log(
        '[DEBUG][PaymentController][loadPlans] Loaded ${_plans.length} plans',
        name: 'PaymentController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][PaymentController][loadPlans] Failed: $e',
        name: 'PaymentController',
        error: e,
      );
    } finally {
      _plansLoading = false;
      notifyListeners();
    }
  }

  /// Get plan by ID
  SubData? getPlanById(String planId) {
    try {
      return _plans.firstWhere((plan) => plan.id.toString() == planId);
    } catch (e) {
      return null;
    }
  }

  /// Get formatted price for plan
  String getFormattedPrice(SubData plan) {
    return '$_currencySym${plan.plan_amount}';
  }

  /// Check if any payment gateway is available
  bool get hasPaymentGateways {
    return _isRazorpayEnabled || _isStripeEnabled || _isPaystackEnabled;
  }

  /// Get available payment methods
  List<String> get availablePaymentMethods {
    List<String> methods = [];
    if (_isRazorpayEnabled) methods.add('Razorpay');
    if (_isStripeEnabled) methods.add('Stripe');
    if (_isPaystackEnabled) methods.add('Paystack');
    return methods;
  }

  /// Load interstitial ad
  Future<void> loadInterstitialAd() async {
    if (!_allowAds || _isLoadingAd) return;

    _isLoadingAd = true;

    try {
      await InterstitialAd.load(
        adUnitId: _getInterstitialAdUnitId(),
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _interstitialAd = ad;
            _isInterstitialAdReady = true;
            _isLoadingAd = false;
            notifyListeners();

            developer.log(
              '[DEBUG][PaymentController][loadInterstitialAd] Ad loaded successfully',
              name: 'PaymentController',
            );

            _interstitialAd!.setImmersiveMode(true);
          },
          onAdFailedToLoad: (LoadAdError error) {
            _isInterstitialAdReady = false;
            _isLoadingAd = false;
            notifyListeners();

            developer.log(
              '[ERROR][PaymentController][loadInterstitialAd] Failed to load ad: $error',
              name: 'PaymentController',
            );
          },
        ),
      );
    } catch (e) {
      _isLoadingAd = false;
      developer.log(
        '[ERROR][PaymentController][loadInterstitialAd] Exception: $e',
        name: 'PaymentController',
        error: e,
      );
    }
  }

  /// Show interstitial ad
  Future<void> showInterstitialAd() async {
    if (!_isInterstitialAdReady || _interstitialAd == null) {
      developer.log(
        '[DEBUG][PaymentController][showInterstitialAd] Ad not ready',
        name: 'PaymentController',
      );
      return;
    }

    try {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (InterstitialAd ad) {
          developer.log(
            '[DEBUG][PaymentController][showInterstitialAd] Ad showed full screen',
            name: 'PaymentController',
          );
        },
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialAdReady = false;
          notifyListeners();

          // Load next ad
          loadInterstitialAd();

          developer.log(
            '[DEBUG][PaymentController][showInterstitialAd] Ad dismissed',
            name: 'PaymentController',
          );
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialAdReady = false;
          notifyListeners();

          developer.log(
            '[ERROR][PaymentController][showInterstitialAd] Failed to show ad: $error',
            name: 'PaymentController',
          );
        },
      );

      await _interstitialAd!.show();
    } catch (e) {
      developer.log(
        '[ERROR][PaymentController][showInterstitialAd] Exception: $e',
        name: 'PaymentController',
        error: e,
      );
    }
  }

  /// Get interstitial ad unit ID
  String _getInterstitialAdUnitId() {
    // Return the appropriate ad unit ID based on platform
    // This should be configured in your app settings
    return 'ca-app-pub-3940256099942544/1033173712'; // Test ad unit ID
  }

  /// Validate payment amount
  bool isValidAmount(String amount) {
    if (amount.isEmpty) return false;

    try {
      final numAmount = double.parse(amount);
      return numAmount > 0;
    } catch (e) {
      return false;
    }
  }

  /// Format amount with currency
  String formatAmount(String amount) {
    if (!isValidAmount(amount)) return '';
    return '$_currencySym$amount';
  }

  /// Check if user needs to pay for download
  bool needsPaymentForDownload(String? price) {
    if (!_allowDownload) return false;
    if (price == null || price.isEmpty || price == '0') return false;
    return true;
  }

  /// Get download price
  String getDownloadPrice(String? price) {
    if (!needsPaymentForDownload(price)) return '';
    return formatAmount(price!);
  }

  /// Process successful payment
  Future<void> onPaymentSuccess({
    required String paymentId,
    required String amount,
    required String planId,
    String? downloadItemId,
  }) async {
    try {
      developer.log(
        '[DEBUG][PaymentController][onPaymentSuccess] Payment successful - ID: $paymentId, Amount: $amount',
        name: 'PaymentController',
      );

      // Here you would typically:
      // 1. Verify payment with your backend
      // 2. Update user subscription status
      // 3. Enable features based on plan
      // 4. If it's a download payment, trigger download

      notifyListeners();
    } catch (e) {
      developer.log(
        '[ERROR][PaymentController][onPaymentSuccess] Failed to process payment success: $e',
        name: 'PaymentController',
        error: e,
      );
    }
  }

  /// Process payment failure
  Future<void> onPaymentFailure({
    required String error,
    String? paymentId,
  }) async {
    developer.log(
      '[ERROR][PaymentController][onPaymentFailure] Payment failed - Error: $error, ID: $paymentId',
      name: 'PaymentController',
    );

    // Handle payment failure
    // Show error to user, log for analytics, etc.
  }

  /// Refresh settings and plans
  Future<void> refresh() async {
    await _loadSettings();
    await loadPlans();
  }

  /// Clean up resources
  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }
}
