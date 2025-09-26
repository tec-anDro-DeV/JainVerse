import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/ThemeMain/appColors.dart';

class ConnectionCheck {
  Future<bool> checkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      } else {
        Fluttertoast.showToast(
          msg: "Internet Connection failed!",
          toastLength: Toast.LENGTH_SHORT,
          timeInSecForIosWeb: 1,
          backgroundColor: appColors().primaryColorApp,
          textColor: Colors.white,
          fontSize: 16.0,
        );

        return false;
      }
    } on SocketException catch (_) {
      Fluttertoast.showToast(
        msg: "Internet Connection failed!!",
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 1,
        backgroundColor: appColors().primaryColorApp,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      return false;
    }
  }
}
