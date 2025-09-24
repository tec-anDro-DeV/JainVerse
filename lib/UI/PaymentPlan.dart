import 'package:flutter/material.dart';
import 'package:jainverse/UI/SubscriptionPlans.dart';

String planName = '', plan_id = '';
String amount = '0';

class Payment extends StatefulWidget {
  Payment(String checkBox, String plan_amount, String planid, {super.key}) {
    planName = checkBox;
    amount = plan_amount;
    plan_id = planid;
  }

  @override
  State<StatefulWidget> createState() {
    return MyState();
  }
}

class MyState extends State<Payment> {
  @override
  void initState() {
    super.initState();
    // Redirect to new subscription plans page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SubscriptionPlans()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
