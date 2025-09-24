import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/presenters/base_presenter.dart';

class DownloadPresenter extends BasePresenter {
  DownloadPresenter() : super();

  // Context-aware method that triggers token-expiration handling
  Future<ModelMusicList> getDownload(BuildContext context, String token) async {
    print('[DownloadPresenter] getDownload called with token: $token');
    Response<String> response = await get<String>(
      AppConstant.BaseUrl + AppConstant.API_DOWNLOADED_MUSIC_LIST,
      options: Options(headers: createAuthHeaders(token)),
      context: context,
    );

    print(
      '[DownloadPresenter] getDownload response: ${response.statusCode} ${response.data}',
    );

    try {
      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        print('[DownloadPresenter] getDownload parsed (200): $parsed');
        return ModelMusicList.fromJson(parsed);
      } else {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        print('[DownloadPresenter] getDownload parsed (non-200): $parsed');
        return ModelMusicList.fromJson(parsed);
      }
    } catch (error) {
      print('[DownloadPresenter] getDownload error: $error');
      return throw UnimplementedError();
    }
  }

  // Legacy method kept for backward compatibility (no context, no automatic token handling)
  Future<ModelMusicList> getDownloadLegacy(String token) async {
    print('[DownloadPresenter] getDownloadLegacy called with token: $token');
    Response<String> response = await dio.get(
      AppConstant.BaseUrl + AppConstant.API_DOWNLOADED_MUSIC_LIST,
      options: Options(
        headers: {
          "Accept": "application/json",
          "authorization": "Bearer $token",
        },
      ),
    );
    print(
      '[DownloadPresenter] getDownloadLegacy response: ${response.statusCode} ${response.data}',
    );

    try {
      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        print('[DownloadPresenter] getDownloadLegacy parsed (200): $parsed');
        return ModelMusicList.fromJson(parsed);
      } else {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        print(
          '[DownloadPresenter] getDownloadLegacy parsed (non-200): $parsed',
        );
        return ModelMusicList.fromJson(parsed);
      }
    } catch (error) {
      print('[DownloadPresenter] getDownloadLegacy error: $error');
      return throw UnimplementedError();
    }
  }

  // Context-aware method that triggers token-expiration handling
  Future<void> addRemoveFromDownload(
    BuildContext context,
    String MusId,
    String token, {
    String tag = "add",
  }) async {
    print(
      '[DownloadPresenter] addRemoveFromDownload called with MusId: $MusId, token: $token, tag: $tag',
    );
    FormData formData;
    formData = FormData.fromMap({AppConstant.music_id: MusId, 'tag': tag});

    Response<String> response = await post<String>(
      AppConstant.BaseUrl + AppConstant.API_ADD_REMOVE_DOWNLOAD_MUSIC,
      data: formData,
      options: Options(headers: createAuthHeaders(token)),
      context: context,
    );
    print(
      '[DownloadPresenter] addRemoveFromDownload response: ${response.statusCode} ${response.data}',
    );

    try {
      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        print('[DownloadPresenter] addRemoveFromDownload parsed: $parsed');

        if (parsed['msg'].contains('Removed')) {
          print(
            '[DownloadPresenter] addRemoveFromDownload: Removed detected in msg',
          );
          // Don't show toast here - let the UI handle the feedback
        } else if (parsed['msg'].contains('Added')) {
          print(
            '[DownloadPresenter] addRemoveFromDownload: Added detected in msg',
          );
          // Don't show toast here - let the UI handle the feedback
        }
      }
    } catch (error) {
      print('[DownloadPresenter] addRemoveFromDownload error: $error');
    }
  }

  // Legacy method kept for backward compatibility (no context)
  Future<void> addRemoveFromDownloadLegacy(
    String MusId,
    String token, {
    String tag = "add",
  }) async {
    print(
      '[DownloadPresenter] addRemoveFromDownloadLegacy called with MusId: $MusId, token: $token, tag: $tag',
    );
    FormData formData = FormData.fromMap({
      AppConstant.music_id: MusId,
      'tag': tag,
    });

    Response<String> response = await dio.post(
      AppConstant.BaseUrl + AppConstant.API_ADD_REMOVE_DOWNLOAD_MUSIC,
      data: formData,
      options: Options(
        headers: {
          "Accept": "application/json",
          "authorization": "Bearer $token",
        },
      ),
    );
    print(
      '[DownloadPresenter] addRemoveFromDownloadLegacy response: ${response.statusCode} ${response.data}',
    );

    try {
      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        print(
          '[DownloadPresenter] addRemoveFromDownloadLegacy parsed: $parsed',
        );
      }
    } catch (error) {
      print('[DownloadPresenter] addRemoveFromDownloadLegacy error: $error');
    }
  }
}
