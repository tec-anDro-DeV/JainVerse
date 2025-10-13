import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';

class ChannelPresenter {
  final SharedPref _sharedPref = SharedPref();

  /// Sends a multipart request to create a channel.
  /// Returns a map with keys: `status` (bool), `msg` (String), `data` (dynamic), `statusCode` (int).
  Future<Map<String, dynamic>> createChannel({
    required String name,
    required String handle,
    File? image,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final uri = Uri.parse('${AppConstant.BaseUrl}create_channel');

      final request = http.MultipartRequest('POST', uri);
      if (token != null && token.toString().isNotEmpty) {
        request.headers['Authorization'] = 'Bearer ${token.toString()}';
      }

      request.fields['name'] = name.trim();
      request.fields['handle'] = handle.trim();

      if (image != null && await image.exists()) {
        final fileStream = http.ByteStream(image.openRead());
        final length = await image.length();
        final multipartFile = http.MultipartFile(
          'image',
          fileStream,
          length,
          filename: image.path.split('/').last,
        );
        request.files.add(multipartFile);
      }

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      final Map<String, dynamic> decoded =
          resp.body.isNotEmpty
              ? jsonDecode(resp.body) as Map<String, dynamic>
              : {};

      return {
        'statusCode': resp.statusCode,
        'status': decoded['status'] == true,
        'msg': decoded['msg']?.toString() ?? '',
        'data': decoded['data'],
        'raw': decoded,
      };
    } catch (e) {
      return {
        'statusCode': 0,
        'status': false,
        'msg': e.toString(),
        'data': null,
      };
    }
  }

  /// Fetches the user's channel information.
  /// Returns a map with keys: `status` (bool), `msg` (String), `data` (dynamic), `statusCode` (int).
  Future<Map<String, dynamic>> getChannel() async {
    try {
      final token = await _sharedPref.getToken();
      final uri = Uri.parse('${AppConstant.BaseUrl}get_channel');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${token.toString()}',
          'Content-Type': 'application/json',
        },
      );

      final Map<String, dynamic> decoded =
          response.body.isNotEmpty
              ? jsonDecode(response.body) as Map<String, dynamic>
              : {};

      return {
        'statusCode': response.statusCode,
        'status': decoded['status'] == true,
        'msg': decoded['msg']?.toString() ?? '',
        'data': decoded['data'],
        'raw': decoded,
      };
    } catch (e) {
      return {
        'statusCode': 0,
        'status': false,
        'msg': e.toString(),
        'data': null,
      };
    }
  }

  /// Deletes user's channel by ID.
  /// Returns a map with keys: `status` (bool), `msg` (String), `data` (dynamic), `statusCode` (int).
  Future<Map<String, dynamic>> deleteChannel(int channelId) async {
    try {
      final token = await _sharedPref.getToken();
      final uri = Uri.parse('${AppConstant.BaseUrl}delete_channel');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${token.toString()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': channelId}),
      );

      final Map<String, dynamic> decoded =
          response.body.isNotEmpty
              ? jsonDecode(response.body) as Map<String, dynamic>
              : {};

      return {
        'statusCode': response.statusCode,
        'status': decoded['status'] == true,
        'msg': decoded['msg']?.toString() ?? '',
        'data': decoded['data'],
        'raw': decoded,
      };
    } catch (e) {
      return {
        'statusCode': 0,
        'status': false,
        'msg': e.toString(),
        'data': null,
      };
    }
  }

  /// Updates user's channel information.
  /// Returns a map with keys: `status` (bool), `msg` (String), `data` (dynamic), `statusCode` (int).
  Future<Map<String, dynamic>> updateChannel({
    required String name,
    required String handle,
    File? image,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final uri = Uri.parse('${AppConstant.BaseUrl}update_channel');

      final request = http.MultipartRequest('POST', uri);
      if (token != null && token.toString().isNotEmpty) {
        request.headers['Authorization'] = 'Bearer ${token.toString()}';
      }

      request.fields['name'] = name.trim();
      request.fields['handle'] = handle.trim();

      if (image != null && await image.exists()) {
        final fileStream = http.ByteStream(image.openRead());
        final length = await image.length();
        final multipartFile = http.MultipartFile(
          'image',
          fileStream,
          length,
          filename: image.path.split('/').last,
        );
        request.files.add(multipartFile);
      }

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      final Map<String, dynamic> decoded =
          resp.body.isNotEmpty
              ? jsonDecode(resp.body) as Map<String, dynamic>
              : {};

      return {
        'statusCode': resp.statusCode,
        'status': decoded['status'] == true,
        'msg': decoded['msg']?.toString() ?? '',
        'data': decoded['data'],
        'raw': decoded,
      };
    } catch (e) {
      return {
        'statusCode': 0,
        'status': false,
        'msg': e.toString(),
        'data': null,
      };
    }
  }
}
