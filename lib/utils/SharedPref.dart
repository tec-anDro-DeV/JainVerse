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
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Remove user session data
    prefs.remove("settings");
    prefs.remove("user");
    prefs.remove("token");
    prefs.remove("settings");
    prefs.remove("boolValue");
    prefs.remove("intValue");
    prefs.remove("doubleValue");
    prefs.remove("profile_complete");
  }

  // Profile completion status
  Future<void> setProfileComplete(bool isComplete) async {
    SharedPreferences sharedPref = await SharedPreferences.getInstance();
    await sharedPref.setBool('profile_complete', isComplete);
  }

  Future<bool> isProfileComplete() async {
    SharedPreferences sharedPref = await SharedPreferences.getInstance();
    // Default to false if not found
    return sharedPref.getBool('profile_complete') ?? false;
  }

  // Remember me functionality
  setRememberMe(bool remember) async {
    SharedPreferences sharedPref = await SharedPreferences.getInstance();
    await sharedPref.setBool('remember_me', remember);
    // Force commit to ensure it's saved immediately
    await sharedPref.commit();
  }
}

Future<bool> getRememberMe() async {
  SharedPreferences sharedPref = await SharedPreferences.getInstance();

  bool result = sharedPref.getBool('remember_me') ?? false;
  return result;
}

setRememberedEmail(String email) async {
  SharedPreferences sharedPref = await SharedPreferences.getInstance();
  await sharedPref.setString('remembered_email', email);
}

Future<String> getRememberedEmail() async {
  SharedPreferences sharedPref = await SharedPreferences.getInstance();
  String result = sharedPref.getString('remembered_email') ?? '';
  return result;
}

setRememberedPassword(String password) async {
  SharedPreferences sharedPref = await SharedPreferences.getInstance();
  await sharedPref.setString('remembered_password', password);
}

Future<String> getRememberedPassword() async {
  SharedPreferences sharedPref = await SharedPreferences.getInstance();
  String result = sharedPref.getString('remembered_password') ?? '';
  return result;
}
