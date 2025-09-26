import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/payment_service.dart';
import 'package:jainverse/utils/PlanUtils.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/widgets/auth/auth_header.dart';

class SubscriptionPlans extends StatefulWidget {
  const SubscriptionPlans({super.key});

  @override
  State<SubscriptionPlans> createState() => _SubscriptionPlansState();
}

class _SubscriptionPlansState extends State<SubscriptionPlans>
    with SingleTickerProviderStateMixin {
  String _selectedPlan = 'Monthly';
  String? _selectedPlanId; // Add selected plan tracking
  late AnimationController _animationController;
  Animation<double> _fadeInAnimation = const AlwaysStoppedAnimation(1.0);
  Animation<Offset> _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);

  // User data
  SharedPref sharePrefs = SharedPref();
  String userEmail = '';
  String userName = '';

  // Payment service
  final PaymentService _paymentService = PaymentService();
  bool _paymentInProgress = false;

  // Audio handler for mini player detection
  AudioPlayerHandler? _audioHandler;

  @override
  void initState() {
    super.initState();

    // Initialize audio handler
    _audioHandler = const MyApp().called();

    _loadUserData();
    _initializePaymentService();
    _fetchPlans();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    // Start animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  Future<void> _fetchPlans() async {
    try {
      final token = await sharePrefs.getToken();
      final ok = await PlanUtils.fetchPlans(token);
      if (ok && mounted) {
        // Auto-select first plan to make UI clearer for users
        final monthly = PlanUtils.getMonthlyPlans();
        final yearly = PlanUtils.getYearlyPlans();
        setState(() {
          if (_selectedPlan == 'Monthly' && monthly.isNotEmpty) {
            _selectedPlanId =
                (monthly[0]['product_id'] != null &&
                        monthly[0]['product_id'].toString().isNotEmpty)
                    ? monthly[0]['product_id'].toString()
                    : monthly[0]['id']?.toString();
          } else if (_selectedPlan == 'Yearly' && yearly.isNotEmpty) {
            _selectedPlanId =
                (yearly[0]['product_id'] != null &&
                        yearly[0]['product_id'].toString().isNotEmpty)
                    ? yearly[0]['product_id'].toString()
                    : yearly[0]['id']?.toString();
          }
        });
      }
    } catch (e) {
      print('Failed to fetch plans: $e');
    }
  }

  /// Initialize payment service
  Future<void> _initializePaymentService() async {
    try {
      await _paymentService.initialize();
      print('PaymentService initialized successfully');
    } catch (e) {
      print('Failed to initialize PaymentService: $e');
    }
  }

  /// Load user data from SharedPreferences
  Future<void> _loadUserData() async {
    try {
      final UserModel user = await sharePrefs.getUserData();
      setState(() {
        userEmail = user.data.email;
        userName = user.data.name;
      });

      // Debug logging
      print('DEBUG: User data loaded - Email: "$userEmail", Name: "$userName"');
    } catch (e) {
      print('Error loading user data: $e');
      // Set default values if user data can't be loaded
      setState(() {
        userEmail = '';
        userName = '';
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final padding = MediaQuery.of(context).padding;
    final safeAreaHeight = screenHeight - padding.top - padding.bottom;

    // Set status bar color to match background
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: appColors().backgroundLogin,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: appColors().backgroundLogin,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar replacement
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      size: 24.w,
                      color: appColors().black,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    "Subscription Plan",
                    style: TextStyle(
                      color: appColors().black,
                      fontSize: AppSizes.fontLarge,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  // Empty SizedBox for balanced spacing
                  SizedBox(width: 48.w),
                ],
              ),
            ),

            // Header with logo
            AuthHeader(
              height: safeAreaHeight * 0.12,
              heroTag: 'subscription_logo',
            ),

            // Content area with rounded top
            Expanded(
              child: FadeTransition(
                opacity: _fadeInAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32.r),
                        topRight: Radius.circular(32.r),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Fixed position tab bar and header
                        Padding(
                          padding: EdgeInsets.only(
                            top: 24.w,
                            left: 24.w,
                            right: 24.w,
                          ),
                          child: Column(
                            children: [
                              // Description text
                              Text(
                                "Choose the perfect plan for your streaming needs",
                                style: TextStyle(
                                  color: appColors().black,
                                  fontSize: AppSizes.fontNormal,
                                  fontFamily: 'Poppins',
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 24.w),

                              // Plan duration tabs
                              PlanTabBar(
                                selectedPlan: _selectedPlan,
                                onPlanChanged: (plan) {
                                  setState(() {
                                    _selectedPlan = plan;
                                    _selectedPlanId =
                                        null; // Reset selection when switching plans
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20.w),

                        // Scrollable content area
                        Expanded(
                          child: StreamBuilder<MediaItem?>(
                            stream: _audioHandler?.mediaItem,
                            builder: (context, snapshot) {
                              return SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    24.w,
                                    0,
                                    24.w,
                                    AppSizes.basePadding,
                                  ),
                                  child: Column(
                                    children: [
                                      // Plans list
                                      ..._buildPlansList(),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Fixed bottom section with continue button
                        StreamBuilder<MediaItem?>(
                          stream: _audioHandler?.mediaItem,
                          builder: (context, snapshot) {
                            // Calculate proper bottom padding accounting for mini player and navigation
                            final hasMiniPlayer = snapshot.hasData;
                            final bottomPadding =
                                hasMiniPlayer
                                    ? AppSizes.basePadding +
                                        AppSizes.miniPlayerPadding +
                                        50.w
                                    : AppSizes.basePadding + 50.w;
                            return Container(
                              padding: EdgeInsets.fromLTRB(
                                24.w,
                                24.w,
                                24.w,
                                bottomPadding,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, -3),
                                  ),
                                ],
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                height: AppSizes.inputHeight,
                                child: ElevatedButton(
                                  onPressed:
                                      _selectedPlanId != null &&
                                              !_paymentInProgress
                                          ? () {
                                            // Handle continue action
                                            _handleContinue();
                                          }
                                          : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        appColors().primaryColorApp,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                    disabledForegroundColor:
                                        Colors.grey.shade600,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.borderRadius,
                                      ),
                                    ),
                                    elevation: 0,
                                  ),
                                  child:
                                      _paymentInProgress
                                          ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                              Text(
                                                'Processing...',
                                                style: TextStyle(
                                                  fontSize: AppSizes.fontLarge,
                                                  fontWeight: FontWeight.w600,
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                            ],
                                          )
                                          : Text(
                                            _selectedPlanId != null
                                                ? 'Continue'
                                                : 'Select a Plan',
                                            style: TextStyle(
                                              fontSize: AppSizes.fontLarge,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPlansList() {
    if (_selectedPlan == 'Monthly') {
      return _buildMonthlyPlans();
    } else {
      return _buildYearlyPlans();
    }
  }

  List<Widget> _buildMonthlyPlans() {
    final monthlyPlans = PlanUtils.getMonthlyPlans();
    if (monthlyPlans.isEmpty) {
      return [
        Container(
          padding: EdgeInsets.all(24.w),
          child: Center(child: Text('No monthly plans available')),
        ),
      ];
    }
    return monthlyPlans.map((plan) => _buildPlanCard(plan)).toList();
  }

  List<Widget> _buildYearlyPlans() {
    final yearlyPlans = PlanUtils.getYearlyPlans();
    if (yearlyPlans.isEmpty) {
      return [
        Container(
          padding: EdgeInsets.all(24.w),
          child: Center(child: Text('No yearly plans available')),
        ),
      ];
    }
    return yearlyPlans.map((plan) => _buildPlanCard(plan)).toList();
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    // Prefer product_id (store product identifier) for iOS IAP. Fallback to id string.
    final dynamic rawProductId = plan['product_id'];
    final planId =
        rawProductId != null && rawProductId.toString().isNotEmpty
            ? rawProductId.toString()
            : plan['id']?.toString() ?? '';
    final isSelected = _selectedPlanId == planId;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanId = planId;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: EdgeInsets.only(bottom: 16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color:
                isSelected ? appColors().primaryColorApp : Colors.grey.shade300,
            width: isSelected ? 2.w : 1.w,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isSelected
                      ? appColors().primaryColorApp.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 2),
              spreadRadius: isSelected ? 1 : 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section with plan name and price
            Container(
              padding: EdgeInsets.all(20.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side - Plan name and featured badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Plan name with animated color
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontSize: AppSizes.fontLarge + 2.sp,
                            fontWeight: FontWeight.w700,
                            color:
                                isSelected
                                    ? appColors().primaryColorApp
                                    : Colors.black87,
                            fontFamily: 'Poppins',
                          ),
                          child: Text(plan['name']),
                        ),
                      ],
                    ),
                  ),

                  // Right side - Price with better alignment
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Price with animated color and smaller dollar sign
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Dollar sign - smaller
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              fontSize:
                                  AppSizes
                                      .fontExtraLarge, // Smaller than the number
                              fontWeight: FontWeight.w600,
                              color:
                                  isSelected
                                      ? appColors().primaryColorApp
                                      : Colors.black87,
                              fontFamily: 'Poppins',
                            ),
                            child: Text('\$'),
                          ),
                          // Price number - larger
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              fontSize: AppSizes.fontH1,
                              fontWeight: FontWeight.w800,
                              color:
                                  isSelected
                                      ? appColors().primaryColorApp
                                      : Colors.black87,
                              fontFamily: 'Poppins',
                            ),
                            child: Text(
                              (plan['price'] ?? '\$0.00')
                                  .toString()
                                  .replaceFirst('\$', ''),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.w),

            // Features section with improved layout
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                children: [
                  // Features list
                  ...((plan['features'] is List)
                          ? plan['features']
                          : [plan['features']])
                      .map<Widget>(
                        (feature) => Container(
                          margin: EdgeInsets.only(bottom: 12.w),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Animated checkmark
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: EdgeInsets.only(top: 1.w, right: 12.w),
                                child: Icon(
                                  Icons.check_circle,
                                  size: 20.w,
                                  color:
                                      isSelected
                                          ? appColors().primaryColorApp
                                          : appColors().primaryColorApp,
                                ),
                              ),

                              // Feature text with better spacing
                              Expanded(
                                child: Text(
                                  feature,
                                  style: TextStyle(
                                    fontSize: AppSizes.fontSmall + 2.sp,
                                    color: appColors().black,
                                    fontFamily: 'Poppins',
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),

                  // Savings section for yearly plans (moved here)
                  if ((plan['raw'] != null && plan['raw']['savings'] != null) ||
                      plan['savings'] != null) ...[
                    Container(
                      margin: EdgeInsets.only(bottom: 12.w),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Checkmark for savings - same as other features
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: EdgeInsets.only(top: 1.w, right: 12.w),
                            child: Icon(
                              Icons.check_circle,
                              size: 20.w,
                              color:
                                  isSelected
                                      ? appColors().primaryColorApp
                                      : appColors().primaryColorApp,
                            ),
                          ),

                          // Savings text - same style as other features
                          Expanded(
                            child: Text(
                              '${plan['raw']?['savings'] ?? plan['savings'] ?? ''}',
                              style: TextStyle(
                                fontSize: AppSizes.fontSmall + 2.sp,
                                color: appColors().black,
                                fontFamily: 'Poppins',
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: 20.w),
          ],
        ),
      ),
    );
  }

  void _handleContinue() async {
    // Handle the continue action - navigate to payment or next step
    if (_selectedPlanId != null) {
      final plan = PlanUtils.getPlanDetailsById(
        _selectedPlanId!,
        _selectedPlan,
      );
      if (plan != null) {
        // Ensure user data is loaded before proceeding
        if (userEmail.isEmpty || userName.isEmpty) {
          print('DEBUG: User data empty, reloading...');
          await _loadUserData();
        }

        // Check again after reload
        if (userEmail.isEmpty || userName.isEmpty) {
          print('DEBUG: User data still empty after reload');

          // Try to get user data directly
          try {
            final UserModel user = await sharePrefs.getUserData();
            final String directEmail = user.data.email;
            final String directName = user.data.name;
            print(
              'DEBUG: Direct user data - Email: "$directEmail", Name: "$directName"',
            );

            if (directEmail.isNotEmpty && directName.isNotEmpty) {
              setState(() {
                userEmail = directEmail;
                userName = directName;
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'User information is incomplete. Please update your profile.',
                  ),
                  duration: Duration(seconds: 3),
                ),
              );
              return;
            }
          } catch (e) {
            print('DEBUG: Error getting user data directly: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Unable to load user information. Please try again.',
                ),
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }
        }

        // Extract plan details
        final planName = plan['name'] ?? '';
        final planId = _selectedPlanId!;
        final priceString = plan['price'] ?? '0';
        final amount = priceString.replaceAll(RegExp(r'[^0-9.]'), '');

        // Final validation - ensure data is not empty
        if (userEmail.isEmpty || userName.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'User information is required for payment. Please log in again.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }

        // Debug logging
        print('DEBUG: Proceeding to payment with:');
        print('DEBUG: Plan Name: "$planName"');
        print('DEBUG: Plan ID: "$planId"');
        print('DEBUG: Amount: "$amount"');
        print('DEBUG: User Email: "$userEmail"');
        print('DEBUG: User Name: "$userName"');
        print('DEBUG: Platform: ${_paymentService.currentPlatform}');

        // Set payment in progress
        setState(() {
          _paymentInProgress = true;
        });

        // Use PaymentService for platform-specific payment
        await _paymentService.startPurchase(
          productId: planId,
          planName: planName,
          amount: amount,
          context: context,
          onSuccess: (planId, paymentId, amount) {
            setState(() {
              _paymentInProgress = false;
            });

            // For Apple IAP, navigation is handled internally by PaymentService
            // For other platforms (Android/Stripe), we may need to handle navigation here
            if (_paymentService.currentPlatform != 'iOS') {
              // Navigate to success screen for non-iOS platforms
              _paymentService.navigateToSuccess(
                context,
                paymentType: 'stripe',
                planId: planId,
                paymentId: paymentId,
                orderId: DateTime.now().millisecondsSinceEpoch.toString(),
                amount: amount,
                paymentData: '', // Will be handled internally
              );
            }
            // For iOS, navigation is already handled in PaymentService._completePurchase
          },
          onError: (error) {
            setState(() {
              _paymentInProgress = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment failed: $error'),
                duration: Duration(seconds: 3),
              ),
            );
          },
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Plan details not found.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a plan first.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

// Custom tab bar for Monthly/Yearly selection
class PlanTabBar extends StatefulWidget {
  final String selectedPlan;
  final Function(String) onPlanChanged;

  const PlanTabBar({
    super.key,
    required this.selectedPlan,
    required this.onPlanChanged,
  });

  @override
  State<PlanTabBar> createState() => _PlanTabBarState();
}

class _PlanTabBarState extends State<PlanTabBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.selectedPlan == 'Monthly' ? 0.0 : 1.0,
    );
  }

  @override
  void didUpdateWidget(PlanTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPlan != widget.selectedPlan) {
      if (widget.selectedPlan == 'Monthly') {
        _animationController.animateTo(0.0);
      } else {
        _animationController.animateTo(1.0);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 65.w,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Stack(
        children: [
          // Animated indicator
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Positioned(
                left:
                    _animationController.value *
                        (MediaQuery.of(context).size.width - 60.w - 8.r) /
                        2 +
                    4.r,
                top: 4.r,
                bottom: 4.r,
                width: (MediaQuery.of(context).size.width - 60.w - 8.r) / 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: appColors().primaryColorApp,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              );
            },
          ),

          // Tab options
          Row(
            children: [
              // Monthly Tab
              Expanded(
                child: GestureDetector(
                  onTap: () => widget.onPlanChanged('Monthly'),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 16.w),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.r),
                      color: Colors.transparent,
                    ),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color:
                              widget.selectedPlan == 'Monthly'
                                  ? Colors.white
                                  : appColors().black,
                          fontSize: AppSizes.fontNormal,
                          fontWeight:
                              widget.selectedPlan == 'Monthly'
                                  ? FontWeight.w800
                                  : FontWeight.w400,
                          fontFamily: 'Poppins',
                        ),
                        child: const Text('Monthly'),
                      ),
                    ),
                  ),
                ),
              ),

              // Yearly Tab
              Expanded(
                child: GestureDetector(
                  onTap: () => widget.onPlanChanged('Yearly'),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 16.w),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.r),
                      color: Colors.transparent,
                    ),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color:
                              widget.selectedPlan == 'Yearly'
                                  ? Colors.white
                                  : appColors().black,
                          fontSize: AppSizes.fontNormal,
                          fontWeight:
                              widget.selectedPlan == 'Yearly'
                                  ? FontWeight.w800
                                  : FontWeight.w400,
                          fontFamily: 'Poppins',
                        ),
                        child: const Text('Yearly'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
