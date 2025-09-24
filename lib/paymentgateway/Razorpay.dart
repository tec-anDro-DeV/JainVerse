// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:jainverse/Model/ModelSettings.dart';
// import 'package:jainverse/Model/UserModel.dart';
// import 'package:jainverse/Presenter/PlanPresenter.dart';
// import 'package:jainverse/ThemeMain/AppSettings.dart';
// import 'package:jainverse/ThemeMain/appColors.dart';
// import 'package:jainverse/UI/PaymentSuccess.dart';
// import 'package:jainverse/utils/AppConstant.dart';
// import 'package:jainverse/utils/SharedPref.dart';
// import 'package:razorpay_flutter/razorpay_flutter.dart';

// String planname = '', plan_id = '';
// double amountPlan = 0, mainAmount = 0, exactPlanAmount = 0;
// String CurrencyCode = 'USD', currSym = '\$', tax = '';
// String coupon_id = '';
// String discount = '', name = '', email = '';

// class Razorpayment extends StatefulWidget {
//   Razorpayment(String planName, String amountToBePaid, String planid, String id,
//       String discoun, String exactAmount, String ema, String nam, {super.key}) {
//     planname = planName;
//     amountPlan = double.parse(amountToBePaid);
//     mainAmount = double.parse(amountToBePaid);
//     plan_id = planid;
//     exactPlanAmount = double.parse(exactAmount);
//     coupon_id = id;
//     discount = discoun;
//     name = nam;
//     email = ema;
//   }

//   @override
//   State<StatefulWidget> createState() {
//     return MyState();
//   }
// }

// class MyState extends State {
//   static const platform = MethodChannel("razorpay_flutter");
//   SharedPref shareprefs = SharedPref();
//   late Razorpay _razorpay;
//   static String token = '';
//   late UserModel model;
//   final int _nowstamp = DateTime.now().millisecondsSinceEpoch;

//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       child: Container(
//         width: MediaQuery.of(context).size.width,
//         color: appColors().colorBackEditText,
//         child: Stack(
//           children: [
//             SizedBox(
//                 width: MediaQuery.of(context).size.width,
//                 height: MediaQuery.of(context).size.height,
//                 child: const Image(
//                   image: AssetImage('assets/gif/tenor2.gif'),
//                 )),
//             Align(
//                 alignment: Alignment.topLeft,
//                 child: Container(
//                   margin: const EdgeInsets.fromLTRB(8, 26, 6, 6),
//                   child: InkResponse(
//                     onTap: () {
//                       Navigator.pop(context);
//                     },
//                     child: Image.asset('assets/icons/backarrow.png',
//                         width: 19,
//                         height: 20,
//                         color: Color(int.parse(AppSettings.colorText))),
//                   ),
//                 )),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> getSettings() async {
//     String? sett = await shareprefs.getSettings();
//     final Map<String, dynamic> parsed = json.decode(sett!);
//     ModelSettings modelSettings = ModelSettings.fromJson(parsed);
//     CurrencyCode = modelSettings.data.currencyCode;
//     currSym = modelSettings.data.currencySymbol;
//     tax = modelSettings.data.tax;
//     if (modelSettings.payment_gateways.razorpay.razorpay_key.isEmpty) {
//       Fluttertoast.showToast(
//           msg: 'Payment details not set up by admin!!',
//           toastLength: Toast.LENGTH_SHORT,
//           timeInSecForIosWeb: 1,
//           backgroundColor: appColors().black,
//           textColor: appColors().white,
//           fontSize: 14.0);
//       Navigator.pop(context);
//     } else {
//       _razorpay = Razorpay();
//       _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
//       _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
//       _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
//       amountPlan = amountPlan * 100;

//       openCheckout(planname, '${amountPlan.round()}',
//           modelSettings.payment_gateways.razorpay.razorpay_key);
//       setState(() {});
//     }
//   }

//   Future<dynamic> value() async {
//     String? sett = await shareprefs.getSettings();
//     final Map<String, dynamic> parsed = json.decode(sett!);
//     ModelSettings modelSettings = ModelSettings.fromJson(parsed);
//     CurrencyCode = modelSettings.data.currencyCode;
//     token = await shareprefs.getToken();
//     model = await shareprefs.getUserData();
//     setState(() {});

//     getSettings();
//     return token;
//   }

//   Future<void> apicall(String payData) async {
//     String res = await PlanPresenter()
//         .singleSongPay("razorpay", plan_id, payData, token);
//     final Map<String, dynamic> parsed = json.decode(res.toString());

//     Navigator.pop(context, "single");
//   }

//   @override
//   void initState() {
//     super.initState();
//     value();
//   }

//   @override
//   void dispose() {
//     super.dispose();
//     _razorpay.clear();
//   }

//   void openCheckout(String planName, String amount, String key) async {
//     var options = {
//       'key': key,
//       'amount': amount,
//       "currency": CurrencyCode,
//       "base_currency": CurrencyCode,
//       'name': AppConstant.appName,
//       'description': planName,
//       'image': 'https://razorpay.com/assets/razorpay-glyph.svg',
//       'prefill': {'contact': model.data.mobile, 'email': model.data.email},
//       'external': {
//         'wallets': ['paytm']
//       }
//     };

//     try {
//       _razorpay.open(options);
//     } catch (e) {}
//   }

//   void _handlePaymentSuccess(PaymentSuccessResponse response) {
//     if (discount.toString().contains("SingleSongPay")) {
//       Fluttertoast.showToast(
//           msg: 'Payment Done! Please wait', toastLength: Toast.LENGTH_LONG);
//       apicall(
//           '[{"order_id":"${response.paymentId}","currency":"$currSym","transaction_id":"${response.paymentId}","payment_id":"${response.paymentId}","amount":"$exactPlanAmount","payment_gateway":"razorpay","status":"1","audio_id":"$plan_id","user_email":"$email","user_name":"$name"}]');
//     } else {
//       String json =
//           '[{"order_id":"$_nowstamp","plan_id":"$plan_id","amount":"$mainAmount","currency":"$currSym","discount":"$discount","taxAmount":"","payment_gateway":"razorpay","user_email":"$email","user_name":"$name","taxPercent":"$tax","plan_exact_amount":"$exactPlanAmount","payment_id":"${response.paymentId}","coupon_id":"$coupon_id","transaction_id":"${response.paymentId}"}]';

//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (context) => PaymentSuccess(
//               'razorpay',
//               plan_id,
//               '${response.paymentId}',
//               '$_nowstamp',
//               amountPlan.toString(),
//               json),
//         ),
//       );
//     }
//   }

//   void _handlePaymentError(PaymentFailureResponse response) {
//     Fluttertoast.showToast(
//         msg: 'Cancel Payment!', toastLength: Toast.LENGTH_SHORT);
//     Navigator.pop(context);
//   }

//   void _handleExternalWallet(ExternalWalletResponse response) {
//     Fluttertoast.showToast(
//         msg: "EXTERNAL_WALLET: ${response.walletName!}",
//         toastLength: Toast.LENGTH_SHORT);
//     Navigator.pop(context);
//   }
// }
