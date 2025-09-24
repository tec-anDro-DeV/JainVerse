import 'dart:io';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ArtistService {
  static const String _baseUrl = AppConstant.BaseUrl;

  Future<Map<String, dynamic>> submitArtistRequest({
    required String firstName,
    required String lastName,
    required String mobile,
    required String dateOfBirth,
    required String gender,
    required String token,
    File? profileImage,
  }) async {
    try {
      var uri = Uri.parse('${_baseUrl}artist-request');
      var request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Add fields
      request.fields['first_name'] = firstName;
      request.fields['last_name'] = lastName;
      request.fields['mobile'] = mobile;
      request.fields['date_of_birth'] = dateOfBirth;
      request.fields['gender'] = gender;

      // Add profile image if provided
      if (profileImage != null && profileImage.path.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('profile_image', profileImage.path),
        );
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      return {
        'success': response.statusCode == 200,
        'data': json.decode(responseData),
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'statusCode': 500};
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String token,
    File? profileImage,
    String? firstName,
    String? lastName,
    String? mobile,
    String? dateOfBirth,
    String? gender,
  }) async {
    try {
      var uri = Uri.parse('${_baseUrl}update-profile');
      var request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Add fields only if they are provided
      if (firstName != null && firstName.isNotEmpty) {
        request.fields['first_name'] = firstName;
      }
      if (lastName != null && lastName.isNotEmpty) {
        request.fields['last_name'] = lastName;
      }
      if (mobile != null && mobile.isNotEmpty) {
        request.fields['mobile'] = mobile;
      }
      if (dateOfBirth != null && dateOfBirth.isNotEmpty) {
        request.fields['date_of_birth'] = dateOfBirth;
      }
      if (gender != null && gender.isNotEmpty) {
        request.fields['gender'] = gender;
      }

      // Add profile image if provided
      if (profileImage != null && profileImage.path.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('profile_image', profileImage.path),
        );
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      return {
        'success': response.statusCode == 200,
        'data': json.decode(responseData),
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'statusCode': 500};
    }
  }
}
