import 'package:flutter/material.dart';
// import 'package:jainverse/paymentgateway/Razorpay.dart';
import 'package:jainverse/Model/ModelSettings.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/paymentgateway/Stripe.dart';

/// Payment gateway selection dialog
class PaymentGatewayDialog extends StatelessWidget {
  final String amount;
  final String itemTitle;
  final String planId;
  final String couponId;
  final String discount;
  final String userEmail;
  final String userName;
  final ModelSettings modelSettings;
  final VoidCallback? onPaymentSuccess;

  const PaymentGatewayDialog({
    super.key,
    required this.amount,
    required this.itemTitle,
    required this.planId,
    required this.couponId,
    required this.discount,
    required this.userEmail,
    required this.userName,
    required this.modelSettings,
    this.onPaymentSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      elevation: 5,
      backgroundColor: appColors().colorBackEditText,
      actionsAlignment: MainAxisAlignment.center,
      content: SizedBox(
        height: 250,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Pay Now Via:',
              style: TextStyle(color: appColors().white, fontSize: 17),
            ),
            _buildUnavailableMessage(),
            _buildPaymentButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildUnavailableMessage() {
    if (_hasNoPaymentGateways()) {
      return Text(
        '\nNot available',
        style: TextStyle(color: appColors().white, fontSize: 15),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildPaymentButtons(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (_hasStripe()) _buildStripeButton(context),
            if (_hasPaystack()) _buildPaystackButton(context),
          ],
        ),
        // Row(
        //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        //   children: [
        //     if (_hasRazorpay()) _buildRazorpayButton(context),
        //     // PayPal button can be added here when needed
        //   ],
        // ),
      ],
    );
  }

  Widget _buildStripeButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 29, 0, 18),
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [appColors().white, appColors().white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: InkResponse(
        onTap: () {
          Navigator.pop(context);
          _navigateToStripe(context);
        },
        child: Image.asset('assets/icons/stripe.png', width: 19, height: 22),
      ),
    );
  }

  Widget _buildPaystackButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 1, 0),
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [appColors().white, appColors().white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: InkResponse(
        onTap: () {
          Navigator.pop(context);
          // PayStack implementation can be added here
        },
        child: Image.asset('assets/icons/paystack.png', width: 19, height: 20),
      ),
    );
  }

  // Widget _buildRazorpayButton(BuildContext context) {
  //   return Container(
  //     margin: const EdgeInsets.fromLTRB(0, 12, 0, 0),
  //     width: 100,
  //     padding: const EdgeInsets.all(12.5),
  //     decoration: BoxDecoration(
  //       gradient: LinearGradient(
  //         colors: [appColors().white, appColors().white, appColors().white],
  //         begin: Alignment.centerLeft,
  //         end: Alignment.centerRight,
  //       ),
  //       borderRadius: BorderRadius.circular(5.0),
  //     ),
  //     child: InkResponse(
  //       onTap: () {
  //         Navigator.pop(context);
  //         _navigateToRazorpay(context);
  //       },
  //       child: Image.asset('assets/icons/razorpay.png', width: 19, height: 22),
  //     ),
  //   );
  // }

  bool _hasNoPaymentGateways() {
    return modelSettings.payment_gateways.razorpay.razorpay_key.isEmpty &&
        modelSettings.payment_gateways.paystack.paystack_public_key.isEmpty &&
        modelSettings.payment_gateways.stripe.stripe_client_id.isEmpty;
  }

  bool _hasStripe() {
    return modelSettings.payment_gateways.stripe.stripe_client_id.isNotEmpty;
  }

  bool _hasPaystack() {
    return modelSettings
        .payment_gateways
        .paystack
        .paystack_public_key
        .isNotEmpty;
  }

  bool _hasRazorpay() {
    return modelSettings.payment_gateways.razorpay.razorpay_key.isNotEmpty;
  }

  void _navigateToStripe(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => StripePay(
              itemTitle,
              amount,
              planId,
              couponId,
              discount,
              amount,
              userEmail,
              userName,
            ),
      ),
    ).then((value) {
      if (value != null) {
        onPaymentSuccess?.call();
      }
    });
  }

  // void _navigateToRazorpay(BuildContext context) {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder:
  //           (context) => Razorpayment(
  //             itemTitle,
  //             amount,
  //             planId,
  //             couponId,
  //             discount,
  //             amount,
  //             userEmail,
  //             userName,
  //           ),
  //     ),
  //   ).then((value) {
  //     if (value != null) {
  //       onPaymentSuccess?.call();
  //     }
  //   });
  // }

  /// Static method to show the dialog
  static Future<bool?> show(
    BuildContext context, {
    required String amount,
    required String itemTitle,
    required String planId,
    required String couponId,
    required String discount,
    required String userEmail,
    required String userName,
    required ModelSettings modelSettings,
    VoidCallback? onPaymentSuccess,
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => PaymentGatewayDialog(
            amount: amount,
            itemTitle: itemTitle,
            planId: planId,
            couponId: couponId,
            discount: discount,
            userEmail: userEmail,
            userName: userName,
            modelSettings: modelSettings,
            onPaymentSuccess: onPaymentSuccess,
          ),
    );
  }
}
