import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:jainverse/Model/ModelPurchaseInfo.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/PurchaseHistoryPresenter.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/widgets/common/app_header.dart';

class PurchaseHistory extends StatefulWidget {
  const PurchaseHistory({super.key});

  @override
  State<StatefulWidget> createState() {
    return purchase_state();
  }
}

class Fact {
  String currency = "";

  Fact(this.currency);

  factory Fact.fromJson(Map<dynamic, dynamic> json) {
    return Fact(json['currency']);
  }
}

class purchase_state extends State {
  SharedPref sharePrefs = SharedPref();
  bool isLoading = true;
  String token = '';
  late UserModel model;
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  List<AudioPurchaseHistory> audioPurchaseHistory = [];
  List<PlanPurchaseHistory> planPurchaseHistory = [];
  List<PlanPurchaseHistory> filteredPlanHistory = [];
  List<AudioPurchaseHistory> filteredAudioHistory = [];
  late DateFormat formatter;
  TextEditingController searchController = TextEditingController();

  // Audio handler for mini player detection
  AudioPlayerHandler? _audioHandler;

  Future<void> apiCall() async {
    String response = await PurchaseHistoryPresenter().purchaseHistoryInfo(
      token,
    );
    if (response.isEmpty) {
      isLoading = false;
      setState(() {});
    } else {
      final Map<String, dynamic> parsed = json.decode(response);
      if (parsed['status'].toString().contains("false")) {
      } else {
        ModelPurchaseInfo purchaseInfo = ModelPurchaseInfo.fromJson(parsed);
        audioPurchaseHistory = purchaseInfo.data.audioPurchaseHistory;
        planPurchaseHistory = purchaseInfo.data.planPurchaseHistory;
        filteredPlanHistory = List.from(planPurchaseHistory);
        filteredAudioHistory = List.from(audioPurchaseHistory);
      }

      isLoading = false;
      setState(() {});
    }
  }

  void _filterHistory(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredPlanHistory = List.from(planPurchaseHistory);
        filteredAudioHistory = List.from(audioPurchaseHistory);
      } else {
        filteredPlanHistory =
            planPurchaseHistory.where((plan) {
              try {
                final Map<String, dynamic> planData = json.decode(
                  plan.plan_data,
                );
                final Map<String, dynamic> paymentData =
                    json.decode(plan.payment_data)[0];
                return plan.order_id.toLowerCase().contains(
                      query.toLowerCase(),
                    ) ||
                    planData["plan_name"].toString().toLowerCase().contains(
                      query.toLowerCase(),
                    ) ||
                    paymentData["payment_gateway"]
                        .toString()
                        .toLowerCase()
                        .contains(query.toLowerCase());
              } catch (e) {
                return false;
              }
            }).toList();

        filteredAudioHistory =
            audioPurchaseHistory.where((audio) {
              try {
                final Map<String, dynamic> audioData = json.decode(
                  audio.audio_data,
                );
                final Map<String, dynamic> paymentData =
                    json.decode(audio.payment_data)[0];
                return audio.order_id.toLowerCase().contains(
                      query.toLowerCase(),
                    ) ||
                    audioData["audio_title"].toString().toLowerCase().contains(
                      query.toLowerCase(),
                    ) ||
                    paymentData["payment_gateway"]
                        .toString()
                        .toLowerCase()
                        .contains(query.toLowerCase());
              } catch (e) {
                return false;
              }
            }).toList();
      }
    });
  }

  value() async {
    token = await sharePrefs.getToken();
    formatter = DateFormat('yyyy-MM-dd');
    try {
      model = await sharePrefs.getUserData();
      sharedPreThemeData = await sharePrefs.getThemeData();
      apiCall();
    } on Exception {}
  }

  @override
  void initState() {
    // Initialize audio handler
    _audioHandler = const MyApp().called();

    value();

    super.initState();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.w),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: searchController,
        onChanged: _filterHistory,
        decoration: InputDecoration(
          hintText: 'Search here...',
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: AppSizes.fontSmall,
            fontFamily: 'Poppins',
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey[500],
            size: AppSizes.iconSize,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 14.w,
          ),
        ),
        style: TextStyle(
          fontSize: AppSizes.fontSmall,
          fontFamily: 'Poppins',
          color: appColors().black,
        ),
      ),
    );
  }

  Widget _buildPlanCard(PlanPurchaseHistory plan) {
    try {
      final Map<String, dynamic> planData = json.decode(plan.plan_data);
      final List<dynamic> paymentList = json.decode(plan.payment_data);
      final Map<String, dynamic> paymentData = paymentList[0];

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.w),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: appColors().white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: appColors().gray[100],
            borderRadius: BorderRadius.circular(12.r),
          ),
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order ID',
                    style: TextStyle(
                      fontSize: AppSizes.fontSmall,
                      fontWeight: FontWeight.w600,
                      color: appColors().black,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    plan.order_id,
                    style: TextStyle(
                      fontSize: AppSizes.fontSmall,
                      fontWeight: FontWeight.w600,
                      color: appColors().primaryColorApp,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.w),
              _buildInfoRow('Plan:', planData['plan_name'] ?? 'N/A'),
              SizedBox(height: 8.w),
              _buildInfoRow(
                'Amount Paid:',
                '${paymentData['amount'] ?? '0'} ${paymentData['currency'] ?? ''}',
              ),
              SizedBox(height: 8.w),
              _buildInfoRow(
                'Payment Gateway:',
                paymentData['payment_gateway']?.toString().toUpperCase() ??
                    'N/A',
              ),
              SizedBox(height: 8.w),
              _buildInfoRow(
                'Devices:',
                planData['num_device']?.toString() ?? '1',
              ),
              SizedBox(height: 8.w),
              _buildInfoRow(
                'Validity (Days):',
                '${planData['validity'] ?? '30'} Days',
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.w),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: appColors().primaryColorApp.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: appColors().primaryColorApp),
        ),
        child: Text(
          'Error loading plan data',
          style: TextStyle(
            color: appColors().primaryColorApp,
            fontSize: AppSizes.fontSmall,
            fontFamily: 'Poppins',
          ),
        ),
      );
    }
  }

  Widget _buildAudioCard(AudioPurchaseHistory audio) {
    try {
      final Map<String, dynamic> audioData = json.decode(audio.audio_data);
      final List<dynamic> paymentList = json.decode(audio.payment_data);
      final Map<String, dynamic> paymentData = paymentList[0];

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.w),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: appColors().white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: appColors().gray[100],
            borderRadius: BorderRadius.circular(12.r),
          ),
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order ID',
                    style: TextStyle(
                      fontSize: AppSizes.fontSmall,
                      fontWeight: FontWeight.w600,
                      color: appColors().black,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    audio.order_id,
                    style: TextStyle(
                      fontSize: AppSizes.fontSmall,
                      fontWeight: FontWeight.w600,
                      color: appColors().primaryColorApp,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.w),
              _buildInfoRow('Audio:', audioData['audio_title'] ?? 'N/A'),
              SizedBox(height: 8.w),
              _buildInfoRow(
                'Amount Paid:',
                '${audioData['download_price'] ?? '0'} ${paymentData['currency'] ?? ''}',
              ),
              SizedBox(height: 8.w),
              _buildInfoRow(
                'Payment Gateway:',
                paymentData['payment_gateway']?.toString().toUpperCase() ??
                    'N/A',
              ),
              SizedBox(height: 8.w),
              _buildInfoRow(
                'Purchase Date:',
                formatter.format(DateTime.parse(audio.created_at)),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.w),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: appColors().primaryColorApp.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: appColors().primaryColorApp),
        ),
        child: Text(
          'Error loading audio data',
          style: TextStyle(
            color: appColors().primaryColorApp,
            fontSize: AppSizes.fontSmall,
            fontFamily: 'Poppins',
          ),
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppSizes.fontSmall,
              fontWeight: FontWeight.w500,
              color: appColors().gray[600],
              fontFamily: 'Poppins',
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: AppSizes.fontSmall,
              fontWeight: FontWeight.w600,
              color: appColors().black,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 32.w),
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: appColors().gray[100],
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48.w,
              color: appColors().gray[400],
            ),
            SizedBox(height: 16.w),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.fontMedium,
                color: appColors().gray[600],
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appColors().white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            AppHeader(
              title: 'Purchase History',
              showBackButton: true,
              showProfileIcon: false,
            ),

            // Content area with rounded top
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32.r),
                    topRight: Radius.circular(32.r),
                  ),
                ),
                child: StreamBuilder<MediaItem?>(
                  stream: _audioHandler?.mediaItem,
                  builder: (context, snapshot) {
                    final hasMiniPlayer = snapshot.hasData;
                    final bottomPadding =
                        hasMiniPlayer
                            ? AppSizes.basePadding + AppSizes.miniPlayerPadding
                            : AppSizes.basePadding;

                    if (isLoading) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: appColors().primaryColorApp,
                        ),
                      );
                    }

                    return Column(
                      children: [
                        // Search Bar
                        _buildSearchBar(),

                        // Content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.only(bottom: bottomPadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Plan Purchase History Section
                                if (filteredPlanHistory.isNotEmpty) ...[
                                  ...filteredPlanHistory.map(
                                    (plan) => _buildPlanCard(plan),
                                  ),
                                  SizedBox(height: 24.w),
                                ],

                                // Audio Purchase History Section
                                if (filteredAudioHistory.isNotEmpty) ...[
                                  Container(
                                    margin: EdgeInsets.symmetric(
                                      horizontal: 20.w,
                                      vertical: 8.w,
                                    ),
                                    child: Text(
                                      'Audio Purchase History',
                                      style: TextStyle(
                                        fontSize: AppSizes.fontLarge,
                                        fontWeight: FontWeight.bold,
                                        color: appColors().black,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                  ...filteredAudioHistory.map(
                                    (audio) => _buildAudioCard(audio),
                                  ),
                                ],

                                // Empty State
                                if (filteredPlanHistory.isEmpty &&
                                    filteredAudioHistory.isEmpty) ...[
                                  if (searchController.text.isNotEmpty)
                                    _buildEmptyState(
                                      'No purchase history found matching your search.',
                                    )
                                  else
                                    _buildEmptyState(
                                      'No purchase history found.',
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
