import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/Model/ArtistVerificationModel.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/presenters/base_presenter.dart';

/// Service to handle artist verification API calls
class ArtistVerificationService extends BasePresenter {
  ArtistVerificationService() : super();

  /// Get verification status for the current user
  Future<VerificationStatusResponse> getVerificationStatus({
    required String token,
    required BuildContext context,
  }) async {
    try {
      final response = await get<String>(
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

  /// Submit verification request with document and certificate URLs
  Future<VerificationSubmissionResponse> submitVerificationRequest({
    required String documentUrl,
    required String certificateUrl,
    required String token,
    required BuildContext context,
  }) async {
    try {
      final requestData = VerificationRequestData(
        document: documentUrl,
        certificate: certificateUrl,
      );

      final response = await post<String>(
        AppConstant.BaseUrl + AppConstant.API_ARTIST_VERIFY_REQUEST,
        data: requestData.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
        context: context,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
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
  Future<VerificationStatusResponse> getVerificationStatusLegacy({
    required String token,
  }) async {
    try {
      final response = await dio.get(
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
  Future<VerificationSubmissionResponse> submitVerificationRequestLegacy({
    required String documentUrl,
    required String certificateUrl,
    required String token,
  }) async {
    try {
      final requestData = VerificationRequestData(
        document: documentUrl,
        certificate: certificateUrl,
      );

      final response = await dio.post(
        AppConstant.BaseUrl + AppConstant.API_ARTIST_VERIFY_REQUEST,
        data: requestData.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
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

  /// Check if user needs to show verification screen
  static bool shouldShowVerificationScreen(
    String artistVerifyStatus,
    bool isArtist,
  ) {
    final normalizedStatus = _normalizeStatus(artistVerifyStatus);

    // Show verification screen if:
    // 1. Status is pending (waiting for review)
    // 2. Status is not_uploaded (documents never submitted)
    // 3. Non-artist users with rejected status may need to resubmit
    if (normalizedStatus == 'pending' || normalizedStatus == 'not_uploaded') {
      return true;
    }

    if (!isArtist && normalizedStatus == 'rejected') {
      return true;
    }

    return false;
  }

  /// Check if user should see "Request as Artist" option
  static bool shouldShowRequestAsArtist(
    String artistVerifyStatus,
    bool isArtist,
  ) {
    final normalizedStatus = _normalizeStatus(artistVerifyStatus);

    // Show "Request as Artist" only if user is not an artist and either:
    // - never submitted documents
    // - previous submission was rejected
    // - no status available
    return !isArtist &&
        (normalizedStatus.isEmpty ||
            normalizedStatus == 'rejected' ||
            normalizedStatus == 'not_uploaded');
  }

  /// Check if user should see "Verify as Artist" option
  static bool shouldShowVerifyAsArtist(
    String artistVerifyStatus,
    bool isArtist,
  ) {
    final normalizedStatus = _normalizeStatus(artistVerifyStatus);

    // Show "Verify as Artist" if:
    // 1. User is an artist AND
    // 2. Documents are pending review, rejected, or not uploaded yet
    if (!isArtist) return false;

    return normalizedStatus == 'pending' ||
        normalizedStatus == 'rejected' ||
        normalizedStatus == 'not_uploaded';
  }

  /// Helper method to convert full status to legacy single character format
  /// This is for backward compatibility with existing code
  static String getStatusCode(String artistVerifyStatus) {
    switch (_normalizeStatus(artistVerifyStatus)) {
      case 'pending':
        return 'P';
      case 'verified':
        return 'A';
      case 'rejected':
        return 'R';
      case 'not_uploaded':
        return 'N';
      default:
        // Treat unknown/empty as not requested (N)
        return 'N';
    }
  }

  /// Helper method to get display-friendly status text
  static String getStatusDisplayText(String artistVerifyStatus) {
    switch (_normalizeStatus(artistVerifyStatus)) {
      case 'pending':
        return 'Pending';
      case 'verified':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'not_uploaded':
        // Use the exact requested label
        return 'Not requested';
      default:
        // Fall back to 'Not requested' for empty/unknown statuses
        return 'Not requested';
    }
  }

  static String _normalizeStatus(String status) {
    final value = status.trim().toLowerCase();

    switch (value) {
      case 'pending':
      case 'p':
        return 'pending';
      case 'verified':
      case 'approved':
      case 'a':
        return 'verified';
      case 'rejected':
      case 'r':
        return 'rejected';
      case 'not uploaded':
      case 'not_uploaded':
      case 'notuploaded':
      case 'n':
        return 'not_uploaded';
      case '':
        // Empty string should be treated as not requested
        return 'not_uploaded';
      default:
        return value;
    }
  }
}
