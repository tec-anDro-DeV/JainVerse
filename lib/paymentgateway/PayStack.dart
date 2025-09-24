// import 'dart:convert';
// import 'dart:io';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:flutter/material.dart';
// import 'package:paystack_flutter_sdk/paystack_flutter_sdk.dart';
// import 'package:jainverse/Presenter/PlanPresenter.dart';

// import '../Model/ModelSettings.dart';
// import '../Model/UserModel.dart';
// import '../ThemeMain/appColors.dart';
// import '../UI/PaymentSuccess.dart';
// import '../utils/SharedPref.dart';

// String planname = '', plan_id = '';
// double amountPlan = 0, mainAmount = 0, exactPlanAmount = 0;
// String CurrencyCode = 'USD', currSym = '\$', tax = '';
// String coupon_id = '';
// String discount = '', name = '', email = '';

// class PayStack extends StatefulWidget {
//   PayStack(
//     String planName,
//     String amountToBePaid,
//     String planid,
//     String id,
//     String discoun,
//     String exactAmount,
//     String ema,
//     String nam, {
//     super.key,
//   }) {
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
//   _PayStackState createState() => _PayStackState();
// }

// class _PayStackState extends State<PayStack> {
//   SharedPref shareprefs = SharedPref();
//   late UserModel model;
//   final plugin = PaystackPlugin();
//   String paystackPublicKey = '';
//   String CurrencyCode = 'USD', currSym = '\$', tax = '';
//   static String token = '';
//   final int _nowstamp = DateTime.now().millisecondsSinceEpoch;

//   @override
//   Widget build(BuildContext context) {
//     return Container();
//   }

//   @override
//   void initState() {
//     super.initState();
//     value();
//   }

//   Future<void> apicall(String payData) async {
//     String res = await PlanPresenter().singleSongPay(
//       "paystack",
//       plan_id,
//       payData,
//       token,
//     );

//     Navigator.pop(context, "single");
//   }

//   value() async {
//     model = await shareprefs.getUserData();
//     String? sett = await shareprefs.getSettings();
//     final Map<String, dynamic> parsed = json.decode(sett!);
//     ModelSettings modelSettings = ModelSettings.fromJson(parsed);
//     CurrencyCode = modelSettings.data.currencyCode;
//     currSym = modelSettings.data.currencySymbol;
//     token = await shareprefs.getToken();
//     if (modelSettings.data.admin_rzp_key.isEmpty) {
//       Fluttertoast.showToast(
//         msg: 'Payment details not set up by admin!!',
//         toastLength: Toast.LENGTH_SHORT,
//         timeInSecForIosWeb: 1,
//         backgroundColor: Colors.grey,
//         textColor: appColors().white,
//         fontSize: 14.0,
//       );
//     } else {
//       paystackPublicKey =
//           modelSettings.payment_gateways.paystack.paystack_public_key;
//       //  paystackPublicKey=""+modelSettings.data.admin_rzp_key;
//       await plugin.initialize(publicKey: paystackPublicKey);
//       initPay();
//     }
//   }

//   initPay() async {
//     int amt = int.parse(mainAmount.round().toString());
//     amt = amt * 100;

//     Charge charge =
//         Charge()
//           ..amount = amt
//           ..reference = _getReference()
//           // or ..accessCode = _getAccessCodeFrmInitialization()
//           ..email = model.data.email;
//     CheckoutResponse response = await plugin.checkout(
//       context,
//       method: CheckoutMethod.card, // Defaults to CheckoutMethod.selectable
//       charge: charge,
//     );

//     bool status = response.status;
//     if (status) {
//       if (discount.toString().contains("SingleSongPay")) {
//         Fluttertoast.showToast(
//           msg: 'Payment Done! Please wait',
//           toastLength: Toast.LENGTH_LONG,
//         );
//         apicall(
//           '[{"order_id":"${response.reference}","currency":"$currSym","transaction_id":"${response.reference}","payment_id":"${response.reference}","amount":"$exactPlanAmount","payment_gateway":"paystack","status":"1","audio_id":"$plan_id","user_email":"$email","user_name":"$name"}]',
//         );
//       } else {
//         String json =
//             '[{"order_id":"$_nowstamp","plan_id":"$plan_id","amount":"$mainAmount","currency":"$currSym","discount":"$discount","taxAmount":"","payment_gateway":"paystack","user_email":"$email","user_name":"$name","taxPercent":"$tax","plan_exact_amount":"$exactPlanAmount","payment_id":"${response.reference}","coupon_id":"$coupon_id","transaction_id":"${response.reference}"}]';
//         //  payment_details="{\"payment_id\" : \""+response.reference.toString()+"\"}";
//         //  paymentid=response.paymentId.toString();
//         // orderPlace();
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder:
//                 (context) => PaymentSuccess(
//                   'paystack',
//                   plan_id,
//                   '${response.reference}',
//                   '$_nowstamp',
//                   amountPlan.toString(),
//                   json,
//                 ),
//           ),
//         );
//       }
//     } else {
//       Navigator.pop(context);
//     }
//   }

//   String _getReference() {
//     String platform;
//     if (Platform.isIOS) {
//       platform = 'iOS';
//     } else {
//       platform = 'Android';
//     }

//     return 'ChargedFrom${platform}_${DateTime.now().millisecondsSinceEpoch}';
//   }
// }
