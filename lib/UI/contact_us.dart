import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/widgets/auth/auth_header.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class ContactUs extends StatefulWidget {
  const ContactUs({super.key});

  @override
  State<ContactUs> createState() => _ContactUsState();
}

class _ContactUsState extends State<ContactUs> {
  // Audio handler for mini player detection
  AudioPlayerHandler? _audioHandler;

  @override
  void initState() {
    super.initState();
    // Initialize audio handler
    _audioHandler = const MyApp().called();
  }

  @override
  Widget build(BuildContext context) {
    final safeAreaHeight =
        MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: appColors().backgroundLogin,
      body: SafeArea(
        child: Column(
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
                    "Contact Us",
                    style: TextStyle(
                      color: appColors().black,
                      fontSize: AppSizes.fontLarge,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(width: 48.w),
                ],
              ),
            ),
            // Header with logo
            AuthHeader(height: safeAreaHeight * 0.12, heroTag: 'contact_logo'),
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
                  // boxShadow: [
                  //   BoxShadow(
                  //     offset: const Offset(0, -3),
                  //     color: Colors.black.withOpacity(0.03),
                  //     blurRadius: 8,
                  //   ),
                  // ],
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 20.w,
                  ),
                  child: StreamBuilder<MediaItem?>(
                    stream: _audioHandler?.mediaItem,
                    builder: (context, snapshot) {
                      // Calculate proper bottom padding accounting for mini player and navigation
                      final hasMiniPlayer = snapshot.hasData;
                      final bottomPadding =
                          hasMiniPlayer
                              ? AppSizes.basePadding +
                                  AppSizes.miniPlayerPadding
                              : AppSizes.basePadding;

                      return SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: bottomPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Contact Options Section
                              GestureDetector(
                                onTap: () async {
                                  final Uri emailLaunchUri = Uri(
                                    scheme: 'mailto',
                                    path: 'info@jainverse.com',
                                  );
                                  await launchUrl(emailLaunchUri);
                                },
                                child: _ContactCard(
                                  icon: Icons.email_outlined,
                                  iconColor: appColors().primaryColorApp,
                                  iconBg: Colors.white,
                                  title: 'Email Us',
                                  subtitle: 'info@jainverse.com',
                                ),
                              ),
                              SizedBox(height: 16.w),
                              GestureDetector(
                                onTap: () async {
                                  final Uri phoneLaunchUri = Uri(
                                    scheme: 'tel',
                                    path: '+12025550186',
                                  );
                                  await launchUrl(phoneLaunchUri);
                                },
                                child: _ContactCard(
                                  icon: Icons.phone_outlined,
                                  iconColor: appColors().primaryColorApp,
                                  iconBg: Colors.white,
                                  title: 'Call Us',
                                  subtitle: '(+1) 202-555-0186',
                                ),
                              ),
                              SizedBox(height: 16.w),
                              GestureDetector(
                                onTap: () async {
                                  const double latitude = 40.045307351216564;
                                  const double longitude = -75.22115988970808;
                                  const String address =
                                      '7007 Valley Ave, Philadelphia, PA 19128, USA';
                                  Uri mapUri;
                                  if (Platform.isIOS) {
                                    // Apple Maps with address as marker label
                                    final encodedAddress = Uri.encodeComponent(
                                      address,
                                    );
                                    mapUri = Uri.parse(
                                      'http://maps.apple.com/?ll=$latitude,$longitude&q=$encodedAddress',
                                    );
                                  } else {
                                    // Google Maps with address as marker label
                                    final encodedAddress = Uri.encodeComponent(
                                      address,
                                    );
                                    mapUri = Uri.parse(
                                      'https://www.google.com/maps/search/?api=1&query=$encodedAddress',
                                    );
                                  }
                                  await launchUrl(
                                    mapUri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                                child: _ContactCard(
                                  icon: Icons.location_on_outlined,
                                  iconColor: appColors().primaryColorApp,
                                  iconBg: Colors.white,
                                  title: 'Walk In',
                                  subtitle:
                                      '7007 Valley Ave, Philadelphia, PA 19128, USA',
                                ),
                              ),
                              SizedBox(height: 32.w),
                              // Social Media Section
                              Text(
                                'Follow us on',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppSizes.fontLarge,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Container(
                                margin: EdgeInsets.only(top: 4.w, bottom: 20.w),
                                height: 3,
                                width: 145.w,
                                decoration: BoxDecoration(
                                  color: appColors().primaryColorApp,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () async {
                                      final Uri url = Uri.parse(
                                        'https://facebook.com',
                                      );
                                      await launchUrl(
                                        url,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    },
                                    child: Container(
                                      width: AppSizes.iconSize * 2.1,
                                      height: AppSizes.iconSize * 2.1,
                                      decoration: BoxDecoration(
                                        color: Color(0xFF4267B2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: SvgPicture.asset(
                                          'assets/icons/facebook.svg',
                                          width: AppSizes.iconSize * 1.3,
                                          height: AppSizes.iconSize * 1.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 18.w),
                                  GestureDetector(
                                    onTap: () async {
                                      final Uri url = Uri.parse(
                                        'https://twitter.com',
                                      );
                                      await launchUrl(
                                        url,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    },
                                    child: Container(
                                      width: AppSizes.iconSize * 2.1,
                                      height: AppSizes.iconSize * 2.1,
                                      decoration: BoxDecoration(
                                        color: Color(0xFF1DA1F2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(12.w),
                                          child: SvgPicture.asset(
                                            'assets/icons/twitter.svg',
                                            width: AppSizes.iconSize * 1.3,
                                            height: AppSizes.iconSize * 1.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 18.w),
                                  GestureDetector(
                                    onTap: () async {
                                      final Uri url = Uri.parse(
                                        'https://linkedin.com',
                                      );
                                      await launchUrl(
                                        url,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    },
                                    child: Container(
                                      width: AppSizes.iconSize * 2.1,
                                      height: AppSizes.iconSize * 2.1,
                                      decoration: BoxDecoration(
                                        color: Color(0xFF0077B5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(12.w),
                                          child: SvgPicture.asset(
                                            'assets/icons/linkedin.svg',
                                            width: AppSizes.iconSize * 1.3,
                                            height: AppSizes.iconSize * 1.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24.w),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;

  const _ContactCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      // Add grey layer here
      child: Container(
        decoration: BoxDecoration(
          color: appColors().gray[100],
          borderRadius: BorderRadius.circular(12.r),
        ),
        padding: EdgeInsets.all(12.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppSizes.iconSize * 0.7),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: AppSizes.iconSize * 1.3,
              ),
            ),
            SizedBox(width: 18.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: AppSizes.fontMedium,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 4.w),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: appColors().gray[600],
                      fontSize: AppSizes.fontSmall,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
