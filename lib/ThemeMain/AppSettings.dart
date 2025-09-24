import 'package:flutter/material.dart';

import 'appColors.dart';

@immutable
class AppSettings {
  static String colorBackground = '0xFFffffff';
  static String colorText = '0xff000000';
  static String colorPrimary = '0xFFff0065';
  static String colorSecondary = '0xFFfe563c';
  static String imageBackground = 'assets/images/default_screen.jpg';

  static ThemeData define() {
    return ThemeData(
      fontFamily: 'Poppins',
      primaryColor: Color(int.parse(colorPrimary)),
      focusColor: appColors().primaryColorApp,
      unselectedWidgetColor: appColors().colorTextHead,
      cardColor: Color(int.parse(colorPrimary)),
      primarySwatch: appColors().primaryColorApp,
      colorScheme: ColorScheme.light(
        primary: Color(int.parse(colorPrimary)),
        secondary: Color(int.parse(colorSecondary)),
        surface: Color(int.parse(colorBackground)),
      ),
    );
  }

  const AppSettings();
}
