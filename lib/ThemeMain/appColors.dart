import 'package:flutter/material.dart';

@immutable
class appColors {
  final white = const MaterialColor(0xFFffffff, <int, Color>{
    50: Color(0xFFffffff),
    100: Color(0xFFffffff),
    200: Color(0xFFffffff),
    300: Color(0xFFffffff),
    400: Color(0xFFffffff),
    500: Color(0xFFffffff),
    600: Color(0xFFffffff),
    700: Color(0xFFffffff),
    800: Color(0xFFffffff),
    900: Color(0xFFffffff),
  });

  final black = const MaterialColor(0xFF000000, <int, Color>{
    50: Color(0xFF000000),
    100: Color(0xFF000000),
    200: Color(0xFF000000),
    300: Color(0xFF000000),
    400: Color(0xFF000000),
    500: Color(0xFF000000),
    600: Color(0xFF000000),
    700: Color(0xFF000000),
    800: Color(0xFF000000),
    900: Color(0xFF000000),
  });
  final primaryColorApp = const MaterialColor(0xFFAC8447, <int, Color>{
    50: Color(0xFFAC8447),
    100: Color(0xFFAC8447),
    200: Color(0xFFAC8447),
    300: Color(0xFFAC8447),
    400: Color(0xFFAC8447),
    500: Color(0xFFAC8447),
    600: Color(0xFFAC8447),
    700: Color(0xFFAC8447),
    800: Color(0xFFAC8447),
    900: Color(0xFFAC8447),
  });
  // final PrimaryDarkColorApp = const MaterialColor(0xFFAC8447, <int, Color>{
  //   50: Color(0xFFAC8447),
  //   100: Color(0xFFAC8447),
  //   200: Color(0xFFAC8447),
  //   300: Color(0xFFAC8447),
  //   400: Color(0xFFAC8447),
  //   500: Color(0xFFAC8447),
  //   600: Color(0xFFAC8447),
  //   700: Color(0xFFAC8447),
  //   800: Color(0xFFAC8447),
  //   900: Color(0xFFAC8447),
  // });
  // final colorAccent = const MaterialColor(0xFFAC8447, <int, Color>{
  //   50: Color(0xFFAC8447),
  //   100: Color(0xFFAC8447),
  //   200: Color(0xFFAC8447),
  //   300: Color(0xFFAC8447),
  //   400: Color(0xFFAC8447),
  //   500: Color(0xFFAC8447),
  //   600: Color(0xFFAC8447),
  //   700: Color(0xFFAC8447),
  //   800: Color(0xFFAC8447),
  //   900: Color(0xFFAC8447),
  // });
  // Use explicit Color values for primary and accent to avoid confusing identical swatches
  // final Color primary = const Color(0xFFAC8447);
  // final Color primaryDark = const Color(0xFFCF3E20);
  //final Color accent = const Color(0xFFAC8447);
  final gray = const MaterialColor(0xFFdddddd, <int, Color>{
    50: Color(0xFFf5f5f5),
    100: Color(0xFFeeeeee),
    200: Color(0xFFe0e0e0),
    300: Color(0xFFcccccc),
    400: Color(0xFFbdbdbd),
    500: Color(0xFF9e9e9e),
    600: Color(0xFF757575),
    700: Color(0xFF616161),
    800: Color(0xFF424242),
    900: Color(0xFF212121),
  });

  // final gray2 = const MaterialColor(0xffcccccc, <int, Color>{
  //   // gray2 was previously defined with inconsistent ARGB values; use a single Color for clarity
  //   50: Color(0xFFEEEEEE),
  //   100: Color(0xFFDDDDDD),
  //   200: Color(0xFFCCCCCC),
  //   300: Color(0xFFBBBBBB),
  //   400: Color(0xFFAAAAAA),
  //   500: Color(0xFF999999),
  //   600: Color(0xFF888888),
  //   700: Color(0xFF666666),
  //   800: Color(0xFF444444),
  //   900: Color(0xFF222222),
  // });

  final colorBorder = const MaterialColor(0xFFcccccc, <int, Color>{
    // Use a single neutral border color for clarity
    50: Color(0xFFCCCCCC),
    100: Color(0xFFCCCCCC),
    200: Color(0xFFCCCCCC),
    300: Color(0xFFCCCCCC),
    400: Color(0xFFCCCCCC),
    500: Color(0xFFCCCCCC),
    600: Color(0xFFCCCCCC),
    700: Color(0xFFCCCCCC),
    800: Color(0xFFCCCCCC),
    900: Color(0xFFCCCCCC),
  });

  final colorHint = const MaterialColor(0xFF000000, <int, Color>{
    50: Color(0xFF000000),
    100: Color(0xFF000000),
    200: Color(0xFF000000),
    300: Color(0xFF000000),
    400: Color(0xFF000000),
    500: Color(0xFF000000),
    600: Color(0xFF000000),
    700: Color(0xFF000000),
    800: Color(0xFF000000),
    900: Color(0xFF000000),
  });
  final colorText = const MaterialColor(0xFF000000, <int, Color>{
    50: Color(0xFF000000),
    100: Color(0xFF000000),
    200: Color(0xFF000000),
    300: Color(0xFF000000),
    400: Color(0xFF000000),
    500: Color(0xFF000000),
    600: Color(0xFF000000),
    700: Color(0xFF000000),
    800: Color(0xFF000000),
    900: Color(0xFF000000),
  });

  final colorTextHead = const MaterialColor(0xFF000000, <int, Color>{
    50: Color(0xFF000000),
    100: Color(0xFF000000),
    200: Color(0xFF000000),
    300: Color(0xFF000000),
    400: Color(0xFF000000),
    500: Color(0xFF000000),
    600: Color(0xFF000000),
    700: Color(0xFF000000),
    800: Color(0xFF000000),
    900: Color(0xFF000000),
  });

  // final buttonText = const MaterialColor(0xFFffffff, <int, Color>{
  //   50: Color(0xFFffffff),
  //   100: Color(0xFFffffff),
  //   200: Color(0xFFffffff),
  //   300: Color(0xFFffffff),
  //   400: Color(0xFFffffff),
  //   500: Color(0xFFffffff),
  //   600: Color(0xFFffffff),
  //   700: Color(0xFFffffff),
  //   800: Color(0xFFffffff),
  //   900: Color(0xFFffffff),
  // });

  final colorBackground = const MaterialColor(0xFFffffff, <int, Color>{
    50: Color(0xFFffffff),
    100: Color(0xFFffffff),
    200: Color(0xFFffffff),
    300: Color(0xFFffffff),
    400: Color(0xFFffffff),
    500: Color(0xFFffffff),
    600: Color(0xFFffffff),
    700: Color(0xFFffffff),
    800: Color(0xFFffffff),
    900: Color(0xFFffffff),
  });

  final colorTextSideDrawer = const MaterialColor(0xFF000000, <int, Color>{
    50: Color(0xFF000000),
    100: Color(0xFF000000),
    200: Color(0xFF000000),
    300: Color(0xFF000000),
    400: Color(0xFF000000),
    500: Color(0xFF000000),
    600: Color(0xFF000000),
    700: Color(0xFF000000),
    800: Color(0xFF000000),
    900: Color(0xFF000000),
  });
  final red = const MaterialColor(0xfffb314f, <int, Color>{
    50: Color(0xfffb314f),
    100: Color(0xfffb314f),
    200: Color(0xfffb314f),
    300: Color(0xfffb314f),
    400: Color(0xfffb314f),
    500: Color(0xfffb314f),
    600: Color(0xfffb314f),
    700: Color(0xfffb314f),
    800: Color(0xfffb314f),
    900: Color(0xfffb314f),
  });

  final colorBackEditText = const MaterialColor(0xFFffffff, <int, Color>{
    50: Color(0xFFffffff),
    100: Color(0xFFffffff),
    200: Color(0xFFffffff),
    300: Color(0xFFffffff),
    400: Color(0xFFffffff),
    500: Color(0xFFffffff),
    600: Color(0xFFffffff),
    700: Color(0xFFffffff),
    800: Color(0xFFffffff),
    900: Color(0xFFffffff),
  });

  // final panelBackground = const MaterialColor(0xFFffffff, <int, Color>{
  //   50: Color(0xFFffffff),
  //   100: Color(0xFFffffff),
  //   200: Color(0xFFffffff),
  //   300: Color(0xFFffffff),
  //   400: Color(0xFFffffff),
  //   500: Color(0xFFffffff),
  //   600: Color(0xFFffffff),
  //   700: Color(0xFFffffff),
  //   800: Color(0xFFffffff),
  //   900: Color(0xFFffffff),
  // });

  // Navigation bar colors
  // final navBackground = const Color(0xFFF5F5F5);
  // final navActiveIcon = const Color(0xFFAC8447);
  // final navInactiveIcon = const Color.fromARGB(255, 129, 129, 129);
  // final navShadow = const Color(
  //   0x33000000,
  // ); // Semi-transparent for softer shadow
  // final navItemBackground = const Color(0xFFFFFFFF);

  // Player colors
  // final playerBackground = const Color(0xFFFFFFFF);
  // final playerProgressActive = const Color(0xFFFF6B6B);
  // final playerProgressInactive = const Color(
  //   0x26FF6B6B,
  // ); // Very light red with opacity
  // final playerShadow = const Color(0x40000000); // Softer shadow
  // final playerGradientStart = const Color(0xFFAC8447);
  // final playerGradientEnd = const Color(0xFFFF6B6B);
  // final playerButtonBackground = const Color(
  //   0x269E9E9E,
  // ); // Very light grey with opacity

  final backgroundLogin = const Color(0xFFFFECEB);
}
