import 'dart:convert';

import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPref {
  setUserData(String jsonString) async {
    SharedPreferences sharedPref = await SharedPreferences.getInstance();
    sharedPref.setString('user', jsonString); //storing
  }

  setSettingsData(String jsonString) async {
    SharedPreferences sharedPref = await SharedPreferences.getInstance();
    sharedPref.setString('settings', jsonString); //storing
  }

  Future<String?> getSettings() async {
    SharedPreferences sharedPref = await SharedPreferences.getInstance();
    String? settings = sharedPref.getString('settings');
    return settings;
  }

  setToken(String token) async {
    SharedPreferences sharedPref = await SharedPreferences.getInstance();
    sharedPref.setString('token', token); //storing
  }

  Future<dynamic> getToken() async {
    SharedPreferences sharedPref = await SharedPreferences.getInstance();
    String? token = sharedPref.getString('token');

    // Add null safety check
    if (token == null || token.isEmpty) {
      return '';
    }

    return token.replaceAll('Bearer ', '');
  }

  setThemeData(String m) async {
    SharedPreferences sharedPref = await SharedPreferences.getInstance();
    sharedPref.setString('theme', m); //storing
  }

  Future<dynamic> getThemeData() async {
    SharedPreferences sharedPref = await SharedPreferences.getInstance();
    if (sharedPref.containsKey('theme')) {
      String? user = sharedPref.getString('theme');
      Map decodeOptions = jsonDecode(user!);
      return ModelTheme.fromJson(decodeOptions);
    } else {
      // Return default theme
      return ModelTheme('', '', '', '', '', '');
    }
  }

  Future<dynamic> getUserData() async {
    try {
      SharedPreferences sharedPref = await SharedPreferences.getInstance();
      String? user = sharedPref.getString('user');

      if (user == null || user.isEmpty) {
        throw Exception('No user data found');
      }

      Map decodeOptions = jsonDecode(user);
      return UserModel.fromJson(decodeOptions);
    } catch (e) {
      print("DEBUG: Error parsing user data: $e");
      rethrow;
    }
  }

  Future<bool> check() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('user')) {
      return true;
    } else {
      return false;
    }
  }

  removeValues() async {
    print(
      "DEBUG SharedPref: removeValues called - preserving remember me data",
    );
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Remove user session data
    prefs.remove("settings");
    prefs.remove("user");
    prefs.remove("token");
    prefs.remove("settings");
    prefs.remove("boolValue");
    prefs.remove("intValue");
    prefs.remove("doubleValue");

    // Verify remember me data is still there
    bool verifyRememberMe = prefs.getBool('remember_me') ?? false;
    String verifyEmail = prefs.getString('remembered_email') ?? '';
    String verifyPassword = prefs.getString('remembered_password') ?? '';

    print(
      "DEBUG SharedPref: After removeValues - remember me: $verifyRememberMe, email: $verifyEmail, password length: ${verifyPassword.length}",
    );

    // Note: Remember me data is intentionally NOT removed during logout
    // prefs.remove("remember_me");
    // prefs.remove("remembered_email");
    // prefs.remove("remembered_password");
  }

  // Remember me functionality
  setRememberMe(bool remember) async {
    print("DEBUG SharedPref: Setting remember me to $remember");
    SharedPreferences sharedPref = await SharedPreferences.getInstance();
    await sharedPref.setBool('remember_me', remember);
    // Force commit to ensure it's saved immediately
    await sharedPref.commit();
    // Verify it was saved
    bool verification = sharedPref.getBool('remember_me') ?? false;
    print("DEBUG SharedPref: Verified remember me saved as: $verification");

    // Additional verification - get a fresh instance to double-check
    SharedPreferences freshInstance = await SharedPreferences.getInstance();
    bool freshVerification = freshInstance.getBool('remember_me') ?? false;
    print("DEBUG SharedPref: Fresh instance verification: $freshVerification");
  }

  Future<bool> getRememberMe() async {
    SharedPreferences sharedPref = await SharedPreferences.getInstance();

    // Debug: Check all keys to see what's stored
    Set<String> allKeys = sharedPref.getKeys();
    print("DEBUG SharedPref: All stored keys: $allKeys");

    // Check if remember_me key exists
    bool hasKey = sharedPref.containsKey('remember_me');
    print("DEBUG SharedPref: Has remember_me key: $hasKey");

    bool result = sharedPref.getBool('remember_me') ?? false;
    print("DEBUG SharedPref: Getting remember me: $result");
    return result;
  }

  setRememberedEmail(String email) async {
    print("DEBUG SharedPref: Setting remembered email: $email");
    SharedPreferences sharedPref = await SharedPreferences.getInstance();
    await sharedPref.setString('remembered_email', email);
    // Verify it was saved
    String verification = sharedPref.getString('remembered_email') ?? '';
    print("DEBUG SharedPref: Verified email saved as: $verification");
  }

  Future<String> getRememberedEmail() async {
    SharedPreferences sharedPref = await SharedPreferences.getInstance();
    String result = sharedPref.getString('remembered_email') ?? '';
    print("DEBUG SharedPref: Getting remembered email: $result");
    return result;
  }

  setRememberedPassword(String password) async {
    print(
      "DEBUG SharedPref: Setting remembered password length: ${password.length}",
    );
    SharedPreferences sharedPref = await SharedPreferences.getInstance();
    await sharedPref.setString('remembered_password', password);
    // Verify it was saved
    String verification = sharedPref.getString('remembered_password') ?? '';
    print(
      "DEBUG SharedPref: Verified password saved with length: ${verification.length}",
    );
  }

  Future<String> getRememberedPassword() async {
    SharedPreferences sharedPref = await SharedPreferences.getInstance();
    String result = sharedPref.getString('remembered_password') ?? '';
    print(
      "DEBUG SharedPref: Getting remembered password length: ${result.length}",
    );
    return result;
  }
}
