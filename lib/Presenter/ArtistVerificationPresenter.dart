import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/Model/ArtistVerificationModel.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/presenters/base_presenter.dart';

/// Presenter class for artist verification following the existing pattern
class ArtistVerificationPresenter extends BasePresenter {
  SharedPref sharePrefs = SharedPref();

  ArtistVerificationPresenter() : super();

  /// Get verification status using context-aware method
  Future<VerificationStatusResponse> getVerificationStatus(
    BuildContext context,
    String token,
  ) async {
    try {
      Response<String> response = await get<String>(
        AppConstant.BaseUrl + AppConstant.API_ARTIST_VERIFY_STATUS,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
        context: context,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        return VerificationStatusResponse.fromJson(parsed);
      } else {
        throw Exception(
          'Failed to get verification status: ${response.statusMessage}',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        'Network error getting verification status: ${e.message}',
      );
    } catch (e) {
      throw Exception('Unexpected error getting verification status: $e');
    }
  }

  /// Submit verification request using context-aware method
  Future<VerificationSubmissionResponse> submitVerificationRequest(
    BuildContext context,
    String documentUrl,
    String certificateUrl,
    String token,
  ) async {
    var formData = FormData.fromMap({
      'document': documentUrl,
      'certificate': certificateUrl,
    });

    try {
      Response<String> response = await post<String>(
        AppConstant.BaseUrl + AppConstant.API_ARTIST_VERIFY_REQUEST,
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
        context: context,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );

        // Show success message
        if (parsed.containsKey('message')) {
          Fluttertoast.showToast(
            msg: parsed['message'],
            toastLength: Toast.LENGTH_SHORT,
            timeInSecForIosWeb: 1,
            backgroundColor: appColors().primaryColorApp,
            textColor: appColors().colorBackground,
            fontSize: 14.0,
          );
        }

        return VerificationSubmissionResponse.fromJson(parsed);
      } else {
        throw Exception(
          'Failed to submit verification request: ${response.statusMessage}',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        'Network error submitting verification request: ${e.message}',
      );
    } catch (e) {
      throw Exception('Unexpected error submitting verification request: $e');
    }
  }

  /// Legacy method for backward compatibility using raw Dio
  Future<VerificationStatusResponse> getVerificationStatusLegacy(
    String token,
  ) async {
    try {
      Response<String> response = await dio.get(
        AppConstant.BaseUrl + AppConstant.API_ARTIST_VERIFY_STATUS,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        return VerificationStatusResponse.fromJson(parsed);
      } else {
        throw Exception(
          'Failed to get verification status: ${response.statusMessage}',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        'Network error getting verification status: ${e.message}',
      );
    } catch (e) {
      throw Exception('Unexpected error getting verification status: $e');
    }
  }

  /// Legacy method for backward compatibility using raw Dio
  Future<VerificationSubmissionResponse> submitVerificationRequestLegacy(
    String documentUrl,
    String certificateUrl,
    String token,
  ) async {
    var formData = FormData.fromMap({
      'document': documentUrl,
      'certificate': certificateUrl,
    });

    try {
      Response<String> response = await dio.post(
        AppConstant.BaseUrl + AppConstant.API_ARTIST_VERIFY_REQUEST,
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );

        // Show success message
        if (parsed.containsKey('message')) {
          Fluttertoast.showToast(
            msg: parsed['message'],
            toastLength: Toast.LENGTH_SHORT,
            timeInSecForIosWeb: 1,
            backgroundColor: appColors().primaryColorApp,
            textColor: appColors().colorBackground,
            fontSize: 14.0,
          );
        }

        return VerificationSubmissionResponse.fromJson(parsed);
      } else {
        throw Exception(
          'Failed to submit verification request: ${response.statusMessage}',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        'Network error submitting verification request: ${e.message}',
      );
    } catch (e) {
      throw Exception('Unexpected error submitting verification request: $e');
    }
  }
}
