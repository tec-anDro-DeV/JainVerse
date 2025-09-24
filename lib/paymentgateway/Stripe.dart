import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:jainverse/Presenter/PlanPresenter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../Model/ModelSettings.dart';
import '../ThemeMain/appColors.dart';
import '../UI/PaymentSuccess.dart';
import '../utils/SharedPref.dart';

String planname = '', plan_id = '';
double amountPlan = 0, mainAmount = 0, exactPlanAmount = 0;
String CurrencyCode = 'USD', currSym = '\$', tax = '';
String coupon_id = '';
String discount = '', name = '', email = '';

class StripePay extends StatefulWidget {
  StripePay(
    String planName,
    String amountToBePaid,
    String planid,
    String id,
    String discoun,
    String exactAmount,
    String ema,
    String nam, {
    super.key,
  }) {
    planname = planName;
    amountPlan = double.parse(amountToBePaid);
    mainAmount = double.parse(amountToBePaid);
    plan_id = planid;
    exactPlanAmount = double.parse(exactAmount);
    coupon_id = id;
    discount = discoun;
    name = nam;
    email = ema;

    // Debug logging to verify parameters are received
    print('DEBUG StripePay Constructor:');
    print('  planName: "$planName"');
    print('  amountToBePaid: "$amountToBePaid"');
    print('  planid: "$planid"');
    print('  coupon id: "$id"');
    print('  discount: "$discoun"');
    print('  exactAmount: "$exactAmount"');
    print('  email (ema): "$ema"');
    print('  name (nam): "$nam"');
    print('  Global email set to: "$email"');
    print('  Global name set to: "$name"');
  }

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<StripePay> {
  bool hasData = false, payLoading = false;
  String secretKey = '';
  Map<String, dynamic>? paymentIntentData;
  late ModelSettings modelSettings;
  SharedPref shareprefs = SharedPref();
  static String token = '';
  final int _nowstamp = DateTime.now().millisecondsSinceEpoch;

  // Instance variables to store user data (backup to global variables)
  String _userEmail = '';
  String _userName = '';
  String _planId = '';
  String _planName = '';

  getValue() async {
    print('DEBUG getValue() called with global values:');
    print('  Global email: "$email"');
    print('  Global name: "$name"');
    print('  Global tax: "$tax"');

    String? sett = await shareprefs.getSettings();
    final Map<String, dynamic> parsed = json.decode(sett!);
    modelSettings = ModelSettings.fromJson(parsed);
    CurrencyCode = modelSettings.data.currencyCode;
    currSym = modelSettings.data.currencySymbol;
    tax = modelSettings.data.tax; // Get tax from settings
    token = await shareprefs.getToken();

    print('DEBUG After loading settings:');
    print('  CurrencyCode: "$CurrencyCode"');
    print('  currSym: "$currSym"');
    print('  tax from settings: "$tax"');
    print('  token length: ${token.length}');

    if (amountPlan.toString().isNotEmpty) {
      double amount = double.parse(amountPlan.toString());
      amountPlan = amount;
    }

    // secretKey=""+modelSettings.data.STRIPE_DETAILS.SECRET_KEY;
    secretKey = modelSettings.payment_gateways.stripe.stripe_secret;
    WidgetsFlutterBinding.ensureInitialized();
    Stripe.publishableKey =
        modelSettings.payment_gateways.stripe.stripe_client_id;
    //  Stripe.publishableKey = ""+modelSettings.data.STRIPE_DETAILS.PUBLIC_KEY;
    Stripe.merchantIdentifier =
        modelSettings
            .payment_gateways
            .stripe
            .stripe_merchant_country_identifier;

    await Stripe.instance.applySettings();

    hasData = true;
    setState(() {});

    print('DEBUG Before makePayment, final values:');
    print('  email: "$email"');
    print('  name: "$name"');
    print('  tax: "$tax"');

    await makePayment();
  }

  Future<void> apicall(String payData) async {
    await PlanPresenter().singleSongPay(
      "stripe",
      plan_id,
      payData,
      token,
      context,
    );
    Navigator.pop(context, "single");
  }

  @override
  void initState() {
    // Save the global values to instance variables for safety
    _userEmail = email;
    _userName = name;
    _planId = plan_id;
    _planName = planname;

    print('DEBUG: _HomeScreenState initState - storing values:');
    print('  _userEmail: "$_userEmail"');
    print('  _userName: "$_userName"');
    print('  _planId: "$_planId"');
    print('  _planName: "$_planName"');

    getValue();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child:
            (hasData && payLoading)
                ? InkWell(
                  onTap: () async {},
                  child: Container(
                    height: 50,
                    width: 210,
                    color: appColors().primaryColorApp,
                    child: const Center(
                      child: Text(
                        'Start Shopping again',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    ),
                  ),
                )
                : Container(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(
                      appColors().primaryColorApp,
                    ),
                    backgroundColor: appColors().gray,
                    strokeWidth: 3.2,
                  ),
                ),
      ),
    );
  }

  Future<void> makePayment() async {
    try {
      paymentIntentData = await createPaymentIntent(
        amountPlan.toString(),
        CurrencyCode,
      ); //json.decode(response.body);

      await Stripe.instance
          .initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
              paymentIntentClientSecret: paymentIntentData!['client_secret'],
              style: ThemeMode.dark,
              merchantDisplayName:
                  modelSettings
                      .payment_gateways
                      .stripe
                      .stripe_merchant_display_name,
              billingDetails: BillingDetails(
                name: name.isNotEmpty ? name : 'User',
                email: email.isNotEmpty ? email : 'user@example.com',
              ),
            ),
          )
          .then((value) {});

      ///now finally display payment sheeet
      displayPaymentSheet();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cancel Payment! Error")));
      Navigator.pop(context);
    }
  }

  displayPaymentSheet() async {
    try {
      await Stripe.instance
          .presentPaymentSheet()
          .then((newValue) {
            print('payment intent${paymentIntentData!['id']}');
            print('payment intent${paymentIntentData!['client_secret']}');
            print('payment intent${paymentIntentData!['amount']}');
            print('payment intent$paymentIntentData');
            //orderPlaceApi(paymentIntentData!['id'].toString());
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("paid successfully")));
            //  payment_details="{\"payment_id\" : \""+paymentIntentData!['id'].toString()+"\"}";
            //orderPlace();

            // Debug logging for payment data
            print('DEBUG: Payment processing with values:');
            print('DEBUG: email = "$email"');
            print('DEBUG: name = "$name"');
            print('DEBUG: tax = "$tax"');
            print('DEBUG: mainAmount = "$mainAmount"');
            print('DEBUG: exactPlanAmount = "$exactPlanAmount"');
            print('DEBUG: discount = "$discount"');
            print('DEBUG: coupon_id = "$coupon_id"');

            if (discount.toString().contains("SingleSongPay")) {
              Fluttertoast.showToast(
                msg: 'Payment Done! Please wait',
                toastLength: Toast.LENGTH_LONG,
              );

              // Use instance variables as fallback if global variables are empty
              final finalEmail = email.isNotEmpty ? email : _userEmail;
              final finalName = name.isNotEmpty ? name : _userName;

              // Get numeric plan ID from string ID for single song payment
              int numericPlanId = PlanPresenter().getNumericPlanId(plan_id);

              apicall(
                '[{"order_id":"${paymentIntentData!['id']}","currency":"$currSym","transaction_id":"${paymentIntentData!['id']}","payment_id":"${paymentIntentData!['id']}","amount":"$exactPlanAmount","payment_gateway":"stripe","status":"1","audio_id":$numericPlanId,"user_email":"$finalEmail","user_name":"$finalName"}]',
              );

              paymentIntentData = null;
            } else {
              // Calculate tax amount if tax percentage is provided
              double taxPercent = 0.0;
              double taxAmount = 0.0;
              double beforeTaxAmount = 0.0;

              if (tax.isNotEmpty && tax != '0') {
                try {
                  taxPercent = double.parse(tax);
                  taxAmount = (mainAmount * taxPercent) / 100;

                  beforeTaxAmount = mainAmount - taxAmount;
                  print(
                    'DEBUG: Tax calculation - Percent: $taxPercent%, Amount: \$${taxAmount.toStringAsFixed(2)}',
                  );
                } catch (e) {
                  print('DEBUG: Error parsing tax "$tax": $e');
                  taxPercent = 0.0;
                  taxAmount = 0.0;
                }
              } else {
                print('DEBUG: No tax configured (tax = "$tax")');
              }

              print('DEBUG: Final payment data before JSON creation:');
              print('  order_id: "$_nowstamp"');
              print('  plan_id: "$plan_id"');
              print('  amount: "$mainAmount"');
              print('  currency: "$currSym"');
              print('  discount: "$discount"');
              print('  taxAmount: "${taxAmount.toStringAsFixed(2)}"');
              print('  payment_gateway: "stripe"');
              print('  user_email (global): "$email"');
              print('  user_name (global): "$name"');
              print('  user_email (instance): "$_userEmail"');
              print('  user_name (instance): "$_userName"');
              print('  taxPercent: "${taxPercent.toStringAsFixed(2)}"');
              print('  plan_exact_amount: "$exactPlanAmount"');
              print('  coupon_id: "$coupon_id"');

              // Use instance variables as fallback if global variables are empty
              final finalEmail = email.isNotEmpty ? email : _userEmail;
              final finalName = name.isNotEmpty ? name : _userName;

              print('DEBUG: Final values being used:');
              print('  finalEmail: "$finalEmail"');
              print('  finalName: "$finalName"');

              // Get numeric plan ID from string ID
              int numericPlanId = PlanPresenter().getNumericPlanId(plan_id);

              String json =
                  '[{"order_id":"$_nowstamp","plan_id":$numericPlanId,"amount":"$mainAmount","currency":"$currSym","discount":"$discount","taxAmount":"${taxAmount.toStringAsFixed(2)}","payment_gateway":"stripe","user_email":"$finalEmail","user_name":"$finalName","taxPercent":"${taxPercent.toStringAsFixed(2)}","plan_exact_amount":"${beforeTaxAmount.toStringAsFixed(2)}","payment_id":"${paymentIntentData!['id']}","coupon_id":"$coupon_id","transaction_id":"${paymentIntentData!['id']}"}]';
              String payId = paymentIntentData!['id'].toString();

              print('DEBUG: Final JSON being sent: $json');

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => PaymentSuccess(
                        'Stripe',
                        plan_id, // Keep original string ID for consistency
                        payId,
                        '$_nowstamp',
                        amountPlan.toString(),
                        json,
                      ),
                ),
              );
              paymentIntentData = null;
            }
          })
          .onError((error, stackTrace) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Cancel Payment!")));
            Navigator.pop(context);
          });
    } on StripeException {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(content: Text("Cancelled ")),
      );
    } catch (e) {
      print('$e');
    }
  }

  //  Future<Map<String, dynamic>>
  createPaymentIntent(String amount, String currency) async {
    try {
      Map<String, dynamic> body = {
        'amount': calculateAmount(amount),
        'currency': currency,
        'payment_method_types[]': 'card',
      };

      var response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        body: body,
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );
      print('Create Intent reponse ===> ${response.body.toString()}');
      return jsonDecode(response.body);
    } catch (err) {
      print('err charging user: ${err.toString()}');
    }
  }

  calculateAmount(String amount) {
    final doubleAmount = double.parse(amount);
    final intAmount = (doubleAmount * 100).round();
    return intAmount.toString();
  }
}
