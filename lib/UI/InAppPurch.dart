import 'package:flutter/material.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/utils/SharedPref.dart';

class InAppPurch extends StatefulWidget {
  final String email;
  final String name;

  const InAppPurch(this.email, this.name, {super.key});

  @override
  _InAppPurchState createState() => _InAppPurchState();
}

class _InAppPurchState extends State<InAppPurch> {
  final SharedPref sharePrefs = SharedPref();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize in-app purchase functionality here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Subscription Plans"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_outlined),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(color: appColors().colorBackground),
        child:
            isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Premium Subscription",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: appColors().colorTextHead,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Access to all premium features",
                              style: TextStyle(
                                fontSize: 16,
                                color: appColors().colorTextHead,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: appColors().primaryColorApp,
                              ),
                              onPressed: () {
                                // Handle subscription purchase
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Subscription processing initiated",
                                    ),
                                  ),
                                );
                              },
                              child: const Text("Subscribe Now"),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Add more subscription options here
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Monthly Plan",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: appColors().colorTextHead,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Auto-renews monthly",
                              style: TextStyle(
                                fontSize: 16,
                                color: appColors().colorTextHead,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: appColors().primaryColorApp,
                              ),
                              onPressed: () {
                                // Handle subscription purchase
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Monthly subscription processing initiated",
                                    ),
                                  ),
                                );
                              },
                              child: const Text("Subscribe Monthly"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
