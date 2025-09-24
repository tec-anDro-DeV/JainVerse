import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/presenters/base_presenter.dart';

class PlanPresenter extends BasePresenter {
  // New method with token expiration handling
  Future<String> getAllPlans(String token, BuildContext context) async {
    try {
      Response<dynamic> response = await get<dynamic>(
        AppConstant.BaseUrl + AppConstant.API_PLAN_LIST,
        options: Options(headers: createAuthHeaders(token)),
        context: context,
      );

      // Defensive: response.data can be String or already decoded Map/List.
      final raw = response.data;
      try {
        // ignore: avoid_print
        print(
          '[PlanPresenter] getAllPlans response.data runtimeType=${raw.runtimeType}',
        );
      } catch (_) {}

      if (raw == null) return '';
      if (raw is String) return raw;
      // If it's not a string, stringify it so callers get consistent type
      return json.encode(raw);
    } catch (error) {
      throw UnimplementedError();
    }
  }

  // Legacy method for backward compatibility (without token expiration handling)
  Future<String> getAllPlansLegacy(String token) async {
    try {
      final Response<dynamic> response = await dio.get(
        AppConstant.BaseUrl + AppConstant.API_PLAN_LIST,
        options: Options(headers: createAuthHeaders(token)),
      );

      final raw = response.data;
      try {
        // ignore: avoid_print
        print(
          '[PlanPresenter] getAllPlansLegacy response.data runtimeType=${raw.runtimeType}',
        );
      } catch (_) {}

      if (raw == null) return '';
      if (raw is String) return raw;
      return json.encode(raw);
    } catch (error) {
      throw UnimplementedError();
    }
  }

  // New method with token expiration handling
  Future<String> getAllCoupons(String token, BuildContext context) async {
    try {
      Response<String> response = await get<String>(
        AppConstant.BaseUrl + AppConstant.API_GET_COUPON_LIST,
        options: Options(headers: createAuthHeaders(token)),
        context: context,
      );

      if (response.statusCode == 200) {
        return response.data.toString();
      } else {
        return response.data.toString();
      }
    } catch (error) {
      throw UnimplementedError();
    }
  }

  // Legacy method for backward compatibility (without token expiration handling)
  Future<String> getAllCouponsLegacy(String token) async {
    try {
      final response = await dio.get(
        AppConstant.BaseUrl + AppConstant.API_GET_COUPON_LIST,
        options: Options(headers: createAuthHeaders(token)),
      );

      if (response.statusCode == 200) {
        return response.data.toString();
      } else {
        return response.data.toString();
      }
    } catch (error) {
      throw UnimplementedError();
    }
  }

  Future<String> addPlanCoupon(
    String couponCode,
    String token,
    BuildContext context,
  ) async {
    print('token  $token');
    FormData formData = FormData.fromMap({AppConstant.coupon_code: couponCode});

    try {
      Response<String> response = await post<String>(
        AppConstant.BaseUrl + AppConstant.API_USER_COUPON_CODE,
        data: formData,
        options: Options(headers: createAuthHeaders(token)),
        context: context,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );

        if (parsed['status'].toString().contains('false')) {
          Fluttertoast.showToast(
            msg: parsed['msg'],
            toastLength: Toast.LENGTH_SHORT,
            timeInSecForIosWeb: 1,
            backgroundColor: appColors().black,
            textColor: appColors().colorBackground,
            fontSize: 14.0,
          );
        }

        return response.data.toString();
      }
      return response.data.toString();
    } catch (error) {
      return '';
    }
  }

  Future<String> savePlan(
    String type,
    String planId,
    String paymentData,
    String orderId,
    String token,
    BuildContext context,
  ) async {
    // Parse the paymentData string if it's a JSON string
    dynamic parsedPaymentData;
    try {
      parsedPaymentData = json.decode(paymentData);
    } catch (e) {
      debugPrint('[savePlan] Error parsing paymentData: $e');
      // If not valid JSON, keep as string
      parsedPaymentData = paymentData;
    }

    // Get the numeric plan ID from the plan identifier string
    int numericPlanId = _getNumericPlanId(planId);

    // Create API request body according to exact format expected by the API
    Map<String, dynamic> requestBody = {
      "type": type,
      "plan_id": numericPlanId, // Send as numeric value
      "payment_data": parsedPaymentData,
      "order_id": orderId,
    };

    debugPrint('[savePlan] Sending data:');
    debugPrint('type: $type');
    debugPrint('planId: $planId');
    debugPrint('paymentData: $paymentData');
    debugPrint('orderId: $orderId');
    debugPrint('token: $token');
    debugPrint(
      'API Endpoint: ${AppConstant.BaseUrl}${AppConstant.API_SAVE_PAYMENT_TRANSACTION}',
    );

    try {
      // Configure Dio to not throw exceptions on status 500
      dio.options.validateStatus = (status) => status! < 600;

      Response<String> response = await post<String>(
        AppConstant.BaseUrl + AppConstant.API_SAVE_PAYMENT_TRANSACTION,
        data: json.encode(requestBody), // Encode as JSON string
        options: Options(headers: createJsonAuthHeaders(token)),
        context: context,
      );

      debugPrint('[savePlan] Received response:');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Response data: ${response.data}');

      if (response.statusCode == 500) {
        debugPrint('[savePlan] Server error 500. Response: ${response.data}');
        Fluttertoast.showToast(
          msg: "Server error. Please try again later.",
          toastLength: Toast.LENGTH_SHORT,
          timeInSecForIosWeb: 1,
          backgroundColor: appColors().black,
          textColor: appColors().colorBackground,
          fontSize: 14.0,
        );
        return '{"status":false,"msg":"Server error. Please try again later."}';
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );

        Fluttertoast.showToast(
          msg: parsed['msg'] ?? "Payment processed successfully",
          toastLength: Toast.LENGTH_SHORT,
          timeInSecForIosWeb: 1,
          backgroundColor: appColors().black,
          textColor: appColors().colorBackground,
          fontSize: 14.0,
        );

        return response.data.toString();
      }
      return response.data.toString();
    } catch (error) {
      debugPrint('[savePlan] Error: $error');
      Fluttertoast.showToast(
        msg: "Connection error. Please check your internet and try again.",
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 1,
        backgroundColor: appColors().black,
        textColor: appColors().colorBackground,
        fontSize: 14.0,
      );
      return '{"status":false,"msg":"Connection error"}';
    }
  }

  Future<String> singleSongPay(
    String paymentGateway,
    String id,
    String paymentData,
    String token,
    BuildContext context,
  ) async {
    print(" data--  $paymentGateway  , $paymentData   $id   ,  $token");
    FormData formData = FormData.fromMap({
      "audio_id": id,
      "payment_gateway": paymentGateway,
      "payment_data": paymentData,
      "status": 1,
    });

    try {
      Response<String> response = await post<String>(
        AppConstant.BaseUrl + AppConstant.API_buy_audio_to_download,
        data: formData,
        options: Options(headers: createAuthHeaders(token)),
        context: context,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );

        Fluttertoast.showToast(
          msg: parsed['msg'],
          toastLength: Toast.LENGTH_SHORT,
          timeInSecForIosWeb: 1,
          backgroundColor: appColors().black,
          textColor: appColors().colorBackground,
          fontSize: 14.0,
        );

        return response.data.toString();
      }
      return response.data.toString();
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Something went wrong.",
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 1,
        backgroundColor: appColors().black,
        textColor: appColors().colorBackground,
        fontSize: 14.0,
      );

      return '';
    }
  }

  // Helper method to convert plan string ID to numeric ID expected by backend
  int _getNumericPlanId(String planId) {
    return getNumericPlanId(planId);
  }

  // Public method to convert plan string ID to numeric ID expected by backend
  int getNumericPlanId(String planId) {
    // Map plan string IDs to numeric IDs based on backend expectations
    Map<String, int> planMapping = {
      'standard_monthly': 1,
      'family_monthly': 2,
      'student_monthly': 3,
      'standard_yearly': 4,
      'family_yearly': 5,
      'student_yearly': 6,
    };

    // Return the numeric ID from the mapping, or 1 as fallback
    return planMapping[planId] ?? 1;
  }
}
