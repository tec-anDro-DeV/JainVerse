import 'package:flutter/material.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/PlanPresenter.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'dart:async';
import 'dart:convert';
import 'HomeDiscover.dart';
import 'package:jainverse/ThemeMain/appColors.dart';

String plan_id = '';
String payment_id = '';
String order_id = '';
String amountPaid = '';
String jsonpayData = '';
String payment_type = 'stripe';

class PaymentSuccess extends StatefulWidget {
  PaymentSuccess(
    String paymentType,
    String planId,
    String paymentId,
    String orderId,
    String amountToPaid,
    String jsonData, {
    super.key,
  }) {
    plan_id = planId;
    payment_id = paymentId;
    order_id = orderId;
    amountPaid = amountToPaid;
    jsonpayData = jsonData;
    payment_type = paymentType;
  }

  @override
  State<StatefulWidget> createState() {
    return MyState();
  }
}

class MyState extends State<PaymentSuccess> {
  static String token = '';
  late UserModel model;
  SharedPref sharePrefs = SharedPref();

  int _secondsRemaining = 3;
  bool _isPaymentProcessing = true;
  bool _paymentSuccess = false;
  String _errorMessage = "";
  Timer? _navigationTimer;

  Future<void> api() async {
    try {
      if (!mounted) return;
      setState(() {
        _isPaymentProcessing = true;
      });
      final result = await PlanPresenter().savePlan(
        payment_type,
        plan_id,
        jsonpayData,
        order_id,
        token,
        context,
      );
      final Map<String, dynamic> parsed = json.decode(result);
      if (!mounted) return;
      setState(() {
        _isPaymentProcessing = false;
        _paymentSuccess =
            parsed['status'] == true || !result.contains('"status":false');
        if (!_paymentSuccess) {
          _errorMessage = parsed['msg'] ?? "Payment processing failed";
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isPaymentProcessing = false;
        _paymentSuccess = false;
        _errorMessage = "Payment processing failed. Please try again.";
      });
    }
  }

  Future<dynamic> value() async {
    try {
      token = await sharePrefs.getToken();
      model = await sharePrefs.getUserData();
      if (mounted) {
        await api();
      }
      return token;
    } catch (error) {
      return token;
    }
  }

  void _startNavigationTimer() {
    _navigationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          timer.cancel();
          _navigateToHome();
        }
      });
    });
  }

  void _navigateToHome() {
    MusicPlayerStateManager().showNavigationAndMiniPlayer();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeDiscover()),
    );
  }

  @override
  void initState() {
    super.initState();

    // Check if we already have the payment data in jsonpayData
    // If not empty, then this is called from the regular payment flow
    // If empty, we need to construct it (from Apple IAP)
    if (jsonpayData.isEmpty && payment_type == 'apple_iap') {
      // This is likely from Apple IAP where the payment was already processed
      // We can skip the API call and go directly to success
      setState(() {
        _isPaymentProcessing = false;
        _paymentSuccess = true;
      });
      _startNavigationTimer();
    } else {
      // Regular flow - process the payment data
      value().then((_) {
        if (mounted && _paymentSuccess) {
          _startNavigationTimer();
        }
      });
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child:
            _isPaymentProcessing
                ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Processing Payment...'),
                  ],
                )
                : !_paymentSuccess
                ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: Colors.black),
                    SizedBox(height: 16),
                    Text('Payment Failed'),
                    SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(_errorMessage, textAlign: TextAlign.center),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        _navigationTimer?.cancel();
                        _navigateToHome();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: appColors().black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(),
                      ),
                      child: Text('Return to Home'),
                    ),
                  ],
                )
                : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 60, color: Colors.black),
                    SizedBox(height: 16),
                    Text('Success!'),
                    SizedBox(height: 8),
                    Text('Plan purchased successfully'),
                    SizedBox(height: 24),
                    Text('Redirecting in $_secondsRemaining...'),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        _navigationTimer?.cancel();
                        _navigateToHome();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: appColors().black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(),
                      ),
                      child: Text('Continue Now'),
                    ),
                  ],
                ),
      ),
    );
  }
}
