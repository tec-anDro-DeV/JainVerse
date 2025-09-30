import 'package:flutter/material.dart';

import 'appColors.dart';

@immutable
class AppSettings {
  // static String colorText = appColors().black.toString();
  static String imageBackground = 'assets/images/default_screen.jpg';

  static ThemeData define() {
    return ThemeData(
      fontFamily: 'Poppins',
      primaryColor: appColors().primaryColorApp,
      focusColor: appColors().primaryColorApp,
      unselectedWidgetColor: appColors().colorTextHead,
      cardColor: appColors().primaryColorApp,
      primarySwatch: appColors().primaryColorApp,
      colorScheme: ColorScheme.light(
        primary: appColors().primaryColorApp,
        secondary: appColors().primaryColorApp,
        surface: Colors.white,
      ),
    );
  }

  const AppSettings();
}
