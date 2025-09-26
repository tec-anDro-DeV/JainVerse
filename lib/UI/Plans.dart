import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Resources/Strings/StringsLocalization.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/widgets/auth/auth_header.dart';
import 'package:jainverse/widgets/auth/auth_tabbar.dart';
import 'package:we_slide/we_slide.dart';

import '../main.dart';
import 'MainNavigation.dart';
import 'MusicEntryPoint.dart';
import 'PaymentPlan.dart';

AudioPlayerHandler? _audioHandler;

// Static plan data
class PlanData {
  final String name;
  final double monthlyPrice;
  final double yearlyPrice;
  final List<String> features;
  final bool isFeatured;
  final String deviceInfo;
  final String streamInfo;

  PlanData({
    required this.name,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.features,
    this.isFeatured = false,
    required this.deviceInfo,
    required this.streamInfo,
  });
}

class GoPro extends StatefulWidget {
  const GoPro({super.key});

  @override
  State<StatefulWidget> createState() {
    return MyState();
  }
}

class MyState extends State<GoPro> with SingleTickerProviderStateMixin {
  SharedPref sharePrefs = SharedPref();
  late UserModel model;
  String token = '';
  String _selectedPeriod = 'Monthly';
  String? selectedPlanId;

  // Animation controller for UI animations
  late AnimationController _animationController;
  Animation<double> _fadeInAnimation = const AlwaysStoppedAnimation(1.0);
  Animation<Offset> _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);

  final WeSlideController _controller = WeSlideController();
  final double _panelMinSize = 0.0;

  // Static plans data
  final List<PlanData> staticPlans = [
    PlanData(
      name: 'Family Pack',
      monthlyPrice: 15.99,
      yearlyPrice: 191.88,
      deviceInfo: '5 devices (2 adults 18+, 3 under 18)',
      streamInfo: '2 devices: 40 streams/day, 3 devices: 60 streams/day',
      isFeatured: true,
      features: [
        '5 devices access',
        'Family sharing',
        'Premium quality audio',
        'Offline downloads',
        'Ad-free experience',
      ],
    ),
    PlanData(
      name: 'Individual Student',
      monthlyPrice: 7.99,
      yearlyPrice: 95.88,
      deviceInfo: '1 device',
      streamInfo: '60 streams/day',
      features: [
        'Student discount',
        '1 device access',
        'Premium quality audio',
        'Offline downloads',
        'Ad-free experience',
      ],
    ),
    PlanData(
      name: 'Standard',
      monthlyPrice: 9.99,
      yearlyPrice: 119.88,
      deviceInfo: '1 device',
      streamInfo: '60 streams/day',
      features: [
        '1 device access',
        'Premium quality audio',
        'Offline downloads',
        'Ad-free experience',
        'High-quality streaming',
      ],
    ),
    PlanData(
      name: 'Church Pack',
      monthlyPrice: 499.00,
      yearlyPrice: 5988.00,
      deviceInfo: '100 devices max (\$4.99/person)',
      streamInfo: '80 streams/day',
      features: [
        '100 devices access',
        'Church community features',
        'Premium quality audio',
        'Offline downloads',
        'Ad-free experience',
      ],
    ),
    PlanData(
      name: 'School Plan Op. A',
      monthlyPrice: 999.00,
      yearlyPrice: 11988.00,
      deviceInfo: '200 devices (\$4.99/student)',
      streamInfo: '60 spd',
      features: [
        '200 devices access',
        'Educational features',
        'Premium quality audio',
        'Offline downloads',
        'Ad-free experience',
      ],
    ),
    PlanData(
      name: 'School Plan Op. B',
      monthlyPrice: 1247.50,
      yearlyPrice: 14970.00,
      deviceInfo: '250 devices (\$4.99/student)',
      streamInfo: '60 spd',
      features: [
        '250 devices access',
        'Educational features',
        'Premium quality audio',
        'Offline downloads',
        'Ad-free experience',
      ],
    ),
    PlanData(
      name: 'School Plan Op. C',
      monthlyPrice: 1996.00,
      yearlyPrice: 23952.00,
      deviceInfo: '400 devices (\$4.99/student)',
      streamInfo: '60 spd',
      features: [
        '400 devices access',
        'Educational features',
        'Premium quality audio',
        'Offline downloads',
        'Ad-free experience',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _audioHandler = const MyApp().called();

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

    // Start the animation after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });

    initializeData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> initializeData() async {
    try {
      token = await sharePrefs.getToken();
      model = await sharePrefs.getUserData();
      setState(() {});
    } catch (e) {
      print("Error initializing data: $e");
    }
  }

  double _getPrice(PlanData plan) {
    return _selectedPeriod == 'Monthly' ? plan.monthlyPrice : plan.yearlyPrice;
  }

  double _getSavings(PlanData plan) {
    double monthlyTotal = plan.monthlyPrice * 12;
    return monthlyTotal - plan.yearlyPrice;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final padding = MediaQuery.of(context).padding;
    final safeAreaHeight = screenHeight - padding.top - padding.bottom;

    return SafeArea(
      child: Scaffold(
        backgroundColor: appColors().backgroundLogin,
        body: WeSlide(
          body: Column(
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
                      "Subscription Plans",
                      style: TextStyle(
                        color: appColors().black,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    // Empty SizedBox for balanced spacing
                    SizedBox(width: 48.w),
                  ],
                ),
              ),

              // Auth Header
              AuthHeader(height: safeAreaHeight * 0.12, heroTag: 'plans_logo'),

              // Main Content
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
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            spreadRadius: 0,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24.w,
                              vertical: 24.w,
                            ),
                            child: Column(
                              children: [
                                // Header Text
                                Text(
                                  'Choose your subscription',
                                  style: TextStyle(
                                    color: const Color(0xFF555555),
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                SizedBox(height: 20.w),

                                // Period Selection Tabs (Monthly/Yearly)
                                AuthTabBar(
                                  selectedRole: _selectedPeriod,
                                  onRoleChanged: (period) {
                                    setState(() {
                                      _selectedPeriod = period;
                                    });
                                  },
                                  options: const ['Monthly', 'Yearly'],
                                ),
                              ],
                            ),
                          ),

                          // Plans List
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24.w),
                              child: ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: staticPlans.length,
                                itemBuilder: (context, index) {
                                  final plan = staticPlans[index];
                                  final isSelected =
                                      selectedPlanId == index.toString();
                                  final price = _getPrice(plan);
                                  final savings = _getSavings(plan);

                                  return Container(
                                    margin: EdgeInsets.only(bottom: 16.w),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16.r),
                                      border: Border.all(
                                        color:
                                            plan.isFeatured
                                                ? appColors().primaryColorApp
                                                : isSelected
                                                ? appColors().primaryColorApp
                                                : const Color(0xFFE5E5E5),
                                        width: plan.isFeatured ? 2 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 8,
                                          spreadRadius: 0,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        onTap: () {
                                          setState(() {
                                            selectedPlanId =
                                                isSelected
                                                    ? null
                                                    : index.toString();
                                          });
                                        },
                                        child: Padding(
                                          padding: EdgeInsets.all(20.w),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Plan Header
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Text(
                                                              plan.name,
                                                              style: TextStyle(
                                                                fontSize: 18.sp,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color:
                                                                    Colors
                                                                        .black,
                                                                fontFamily:
                                                                    'Poppins',
                                                              ),
                                                            ),
                                                            if (plan
                                                                .isFeatured) ...[
                                                              SizedBox(
                                                                width: 8.w,
                                                              ),
                                                              Container(
                                                                padding:
                                                                    EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          8.w,
                                                                      vertical:
                                                                          4.w,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color:
                                                                      appColors()
                                                                          .primaryColorApp,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12.r,
                                                                      ),
                                                                ),
                                                                child: Text(
                                                                  'POPULAR',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        10.sp,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color:
                                                                        Colors
                                                                            .white,
                                                                    fontFamily:
                                                                        'Poppins',
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                        SizedBox(height: 4.w),
                                                        Text(
                                                          plan.deviceInfo,
                                                          style: TextStyle(
                                                            fontSize: 12.sp,
                                                            color: const Color(
                                                              0xFF888888,
                                                            ),
                                                            fontFamily:
                                                                'Poppins',
                                                          ),
                                                        ),
                                                        Text(
                                                          plan.streamInfo,
                                                          style: TextStyle(
                                                            fontSize: 12.sp,
                                                            color: const Color(
                                                              0xFF888888,
                                                            ),
                                                            fontFamily:
                                                                'Poppins',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        '\$${price.toStringAsFixed(2)}',
                                                        style: TextStyle(
                                                          fontSize: 24.sp,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              appColors().black,
                                                          fontFamily: 'Poppins',
                                                        ),
                                                      ),
                                                      Text(
                                                        '/${_selectedPeriod.toLowerCase()}',
                                                        style: TextStyle(
                                                          fontSize: 14.sp,
                                                          color: const Color(
                                                            0xFF888888,
                                                          ),
                                                          fontFamily: 'Poppins',
                                                        ),
                                                      ),
                                                      if (_selectedPeriod ==
                                                              'Yearly' &&
                                                          savings > 0) ...[
                                                        SizedBox(height: 4.w),
                                                        Text(
                                                          'Save \$${savings.toStringAsFixed(2)}',
                                                          style: TextStyle(
                                                            fontSize: 12.sp,
                                                            color: const Color(
                                                              0xFF4CAF50,
                                                            ),
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontFamily:
                                                                'Poppins',
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),

                                              SizedBox(height: 16.w),

                                              // Features List
                                              ...plan.features.map(
                                                (feature) => Padding(
                                                  padding: EdgeInsets.only(
                                                    bottom: 8.w,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 16.w,
                                                        height: 16.w,
                                                        decoration: BoxDecoration(
                                                          color:
                                                              appColors()
                                                                  .primaryColorApp,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: Icon(
                                                          Icons.check,
                                                          size: 12.w,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      SizedBox(width: 12.w),
                                                      Expanded(
                                                        child: Text(
                                                          feature,
                                                          style: TextStyle(
                                                            fontSize: 14.sp,
                                                            color: const Color(
                                                              0xFF555555,
                                                            ),
                                                            fontFamily:
                                                                'Poppins',
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          // Continue Button
                          Padding(
                            padding: EdgeInsets.all(24.w),
                            child: SizedBox(
                              width: double.infinity,
                              height: 56.w,
                              child: ElevatedButton(
                                onPressed:
                                    selectedPlanId != null
                                        ? () {
                                          final selectedPlan =
                                              staticPlans[int.parse(
                                                selectedPlanId!,
                                              )];
                                          final price = _getPrice(selectedPlan);

                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => Payment(
                                                    selectedPlan.name,
                                                    price.toString(),
                                                    selectedPlanId!,
                                                  ),
                                            ),
                                          );
                                        }
                                        : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: appColors().primaryColorApp,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  elevation: 0,
                                  disabledBackgroundColor: appColors()
                                      .primaryColorApp
                                      .withOpacity(0.4),
                                ),
                                child: Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          controller: _controller,
          overlayOpacity: 0.9,
          overlay: true,
          isDismissible: true,
          panelMinSize: _panelMinSize,
          panelMaxSize: MediaQuery.of(context).size.height,
          blur: true,
          appBar: const BottomNavCustom().appBar("Plans", context, 1),
          appBarHeight: AppConstant.appBarHeight,
          footer: const BottomNavCustom(),
          panel: Music(
            _audioHandler,
            "",
            "",
            const [],
            "bottomSlider",
            0,
            true,
            _controller.hide,
          ),
          panelHeader: Container(
            height: 0.0,
            color: appColors().colorBackground,
          ),
        ),
      ),
    );
  }
}

class Resources {
  Resources();

  StringsLocalization get strings {
    switch ('en') {
      case 'ar':
        return ArabicStrings();
      case 'fn':
        return FranchStrings();
      default:
        return EnglishStrings();
    }
  }

  static Resources of(BuildContext context) {
    return Resources();
  }
}
