// import 'dart:convert';
// import 'package:flutter_paypal/flutter_paypal.dart';
// import 'package:flutter/material.dart';
// import 'package:jainverse/Model/ModelSettings.dart';
// import 'package:jainverse/Model/UserModel.dart';
// import 'package:jainverse/Presenter/PlanPresenter.dart';
// import 'package:jainverse/ThemeMain/appColors.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:jainverse/UI/HomeDiscover.dart';
// import 'package:package_info_plus/package_info_plus.dart';
// import 'package:jainverse/utils/AppConstant.dart';
// import 'package:jainverse/utils/SharedPref.dart';

// String planname = '', plan_id = '';
// double amountPlan = 0, mainAmount = 0, exactPlanAmount = 0;
// String currencyCode = 'USD', currSym = '\$', tax = '';
// String coupon_id = '';
// String discount = '', name = '', email = '';

// class Paypal extends StatefulWidget {
//   Paypal(String planName, String amountToBePaid, String planid, String id,
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
//     return paypal();
//   }
// }

// class paypal extends State {
//   static String token = '';
//   late ModelSettings modelSettings;
//   late UserModel _userLoginModel;
//   SharedPref shareprefs = SharedPref();
//   String clientId = "";
//   late final access;
//   late final database;
//   String secretKey = "";
//   final int _nowstamp = DateTime.now().millisecondsSinceEpoch;
//   bool mode = false;
//   String paypal_mode = "";
//   String packageName = "";

//   Future<dynamic> getValue() async {
//     String? sett = await shareprefs.getSettings();
//     _userLoginModel = await shareprefs.getUserData();
//     final Map<String, dynamic> parsed = json.decode(sett!);
//     modelSettings = ModelSettings.fromJson(parsed);

//     PackageInfo packageInfo = await PackageInfo.fromPlatform();
//     packageName = packageInfo.packageName;
//     packageName = "$packageName://paypalpay";

//     currencyCode = modelSettings.data.currencyCode;
//     clientId = modelSettings.payment_gateways.paypal.paypal_client_id;
//     secretKey = modelSettings.payment_gateways.paypal.paypal_secret;
//     paypal_mode = modelSettings.payment_gateways.paypal.paypal_mode;

//     if (paypal_mode.contains("Live") || paypal_mode.contains("live")) {
//       mode = false;
//     } else {
//       mode = true;
//     }

//     setState(() {});
//     token = await shareprefs.getToken();
//     return token;
//   }

//   Future<void> apicall(String payData) async {
//     String res =
//         await PlanPresenter().singleSongPay("paypal", plan_id, payData, token);
//     Navigator.pop(context, "single");
//   }

//   Future<void> APISuccess(String json) async {
// /*  Navigator.of(contextmain).pushReplacement(
//     new MaterialPageRoute(
//       builder: (contextmain) =>
//           PaymentSuccess(
//               'paypal',
//               "" + plan_id.toString(),
//               '' + params["paymentId"].toString(),
//               '' + _nowstamp.toString(),
//               "" + amountPlan.toString(),
//               json),
//     ),
//   );*/

//     await PlanPresenter()
//         .savePlan("paypal", plan_id, json, _nowstamp.toString(), token);
//     Navigator.of(context).pushReplacement(
//       MaterialPageRoute(
//         builder: (contextmain) => const HomeDiscover(),
//       ),
//     );
//   }

//   @override
//   void initState() {
//     getValue();
//     super.initState();
//   }

//   @override
//   Widget build(BuildContext contextmain) {
//     return SafeArea(
//         child: Material(
//             color: appColors().colorBackEditText,
//             child: Column(
//               children: [
//                 InkResponse(
//                   child: Container(
//                     width: MediaQuery.of(contextmain).size.width,
//                     padding: const EdgeInsets.fromLTRB(9, 0, 9, 0),
//                     margin: const EdgeInsets.fromLTRB(16, 36, 16, 12),
//                     height: 44,
//                     alignment: Alignment.center,
//                     decoration: BoxDecoration(
//                         gradient: LinearGradient(
//                           colors: [
//                             appColors().primaryColorApp,
//                             appColors().PrimaryDarkColorApp
//                           ],
//                           begin: Alignment.centerLeft,
//                           end: Alignment.centerRight,
//                         ),
//                         borderRadius: BorderRadius.circular(25.0)),
//                     child: Text(
//                       'Pay Now',
//                       style: TextStyle(
//                           fontFamily: 'OpenSans-Bold',
//                           fontWeight: FontWeight.w600,
//                           fontSize: 15.5,
//                           color: appColors().white),
//                     ),
//                   ),
//                   onTap: () {
//                     Navigator.of(contextmain).push(MaterialPageRoute(
//                         builder: (BuildContext context) => UsePaypal(
//                             sandboxMode: mode,
//                             clientId: clientId,
//                             secretKey: secretKey,
//                             returnURL: packageName,
//                             cancelURL: AppConstant.ImageUrl,
//                             transactions: [
//                               {
//                                 "amount": {
//                                   "total": mainAmount,
//                                   "currency": currencyCode,
//                                   "details": {
//                                     "subtotal": mainAmount,
//                                     "shipping": '0',
//                                     "shipping_discount": 0
//                                   }
//                                 },
//                                 "description": "payments by $name",
//                                 // "payment_options": {
//                                 //   "allowed_payment_method":
//                                 //       "INSTANT_FUNDING_SOURCE"
//                                 // },
//                                 "item_list": {
//                                   "items": [
//                                     {
//                                       "name": "Plan $planname",
//                                       "quantity": 1,
//                                       "price": mainAmount,
//                                       "currency": currencyCode
//                                     }
//                                   ],

//                                   // shipping address is not required though
//                                 }
//                               }
//                             ],
//                             note: "Contact us for any questions on your order.",
//                             onSuccess: (Map params) async {
//                               if (discount
//                                   .toString()
//                                   .contains("SingleSongPay")) {
//                                 Fluttertoast.showToast(
//                                     msg: 'Payment Done! Please wait',
//                                     toastLength: Toast.LENGTH_LONG);

//                                 apicall(
//                                     '[{"order_id":"${params["paymentId"]}","currency":"$currSym","transaction_id":"${params["paymentId"]}","payment_id":"${params["paymentId"]}","amount":"$exactPlanAmount","payment_gateway":"stripe","status":"1","audio_id":"$plan_id","user_email":"$email","user_name":"$name"}]');
//                               } else {
//                                 Fluttertoast.showToast(
//                                     msg: 'Successfully paid amount..',
//                                     toastLength: Toast.LENGTH_SHORT);
//                                 String json =
//                                     '[{"order_id":"$_nowstamp","plan_id":"$plan_id","amount":"$mainAmount","currency":"$currSym","discount":"$discount","taxAmount":"","payment_gateway":"stripe","user_email":"$email","user_name":"$name","taxPercent":"$tax","plan_exact_amount":"$exactPlanAmount","payment_id":"${params["paymentId"]}","coupon_id":"$coupon_id","transaction_id":"${params["paymentId"]}"}]';

//                                 APISuccess(json);
//                               }
//                             },
//                             onError: (error) {
//                               try {
//                                 String myJSON = error.toString();
//                                 myJSON = myJSON.replaceAll('{', '{"');
//                                 myJSON = myJSON.replaceAll(': ', '": "');
//                                 myJSON = myJSON.replaceAll(', ', '", "');
//                                 myJSON = myJSON.replaceAll('}', '"}');
//                                 Navigator.pop(context);
//                                 final Map<String, dynamic> parsed =
//                                     json.decode(myJSON);

//                                 Fluttertoast.showToast(
//                                     textColor: appColors().PrimaryDarkColorApp,
//                                     msg: '${parsed["message"]}, Contact admin!',
//                                     fontSize: 15.5,
//                                     toastLength: Toast.LENGTH_LONG);
//                               } catch (e) {
//                                 Fluttertoast.showToast(
//                                     textColor: appColors().PrimaryDarkColorApp,
//                                     msg:
//                                         'Error in payment- Contact admin!\n$error',
//                                     fontSize: 15.5,
//                                     toastLength: Toast.LENGTH_LONG);
//                               }
//                             },
//                             onCancel: (params) {
//                               Fluttertoast.showToast(
//                                   msg: 'Cancelled',
//                                   toastLength: Toast.LENGTH_SHORT);
//                               Navigator.pop(context);
//                             })));
//                   },
//                 ),
//                 InkResponse(
//                   onTap: () {
//                     Navigator.pop(context);
//                   },
//                   child: Container(
//                     width: MediaQuery.of(context).size.width,
//                     padding: const EdgeInsets.fromLTRB(9, 0, 9, 0),
//                     margin: const EdgeInsets.fromLTRB(16, 36, 16, 0),
//                     height: 44,
//                     alignment: Alignment.center,
//                     decoration: BoxDecoration(
//                         gradient: LinearGradient(
//                           colors: [
//                             appColors().primaryColorApp,
//                             appColors().PrimaryDarkColorApp
//                           ],
//                           begin: Alignment.centerLeft,
//                           end: Alignment.centerRight,
//                         ),
//                         borderRadius: BorderRadius.circular(25.0)),
//                     child: Text(
//                       'Cancel',
//                       style: TextStyle(
//                           fontFamily: 'OpenSans-Bold',
//                           fontWeight: FontWeight.w600,
//                           fontSize: 15.5,
//                           color: appColors().white),
//                     ),
//                   ),
//                 )
//               ],
//             )));
//   }
// }
