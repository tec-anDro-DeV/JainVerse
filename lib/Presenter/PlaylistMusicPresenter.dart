import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/Model/ModelPlayList.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/presenters/base_presenter.dart';
import 'package:jainverse/services/token_expiration_handler.dart';
import 'package:jainverse/utils/AppConstant.dart';

class PlaylistMusicPresenter extends BasePresenter {
  PlaylistMusicPresenter() : super();

  /// Fetch playlists. If [context] is provided, the request will use the
  /// BasePresenter `get` wrapper so token-expiration handling (dialog + auto
  /// logout) can run. If [context] is null, falls back to legacy direct Dio
  /// call for backward compatibility.
  Future<ModelPlayList> getPlayList(
    String token, [
    BuildContext? context,
  ]) async {
    Response<String> response;

    if (context != null) {
      response = await get<String>(
        AppConstant.BaseUrl + AppConstant.API_USER_PLAYLIST,
        options: Options(headers: createAuthHeaders(token)),
        context: context,
      );
    } else {
      // Legacy behaviour - wrap to handle token expiration and Dio errors
      try {
        response = await dio.get(
          AppConstant.BaseUrl + AppConstant.API_USER_PLAYLIST,
          options: Options(headers: createAuthHeaders(token)),
        );

        // Best-effort check for token expiration (will use navigatorKey fallback)
        await TokenExpirationHandler().checkAndHandleResponse(response);
      } on DioException catch (e) {
        // If the error indicates token expiry, handle it and return a safe fallback
        await TokenExpirationHandler().checkAndHandleResponse(e.response);
        return ModelPlayList(false, '', [], '', '');
      }
    }

    try {
      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        return ModelPlayList.fromJson(parsed);
      } else {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        return ModelPlayList.fromJson(parsed);
      }
    } catch (error) {
      // Return an empty playlist on parse/failure to avoid crashing the app.
      return ModelPlayList(false, '', [], '', '');
    }
  }

  Future<void> createPlaylist(String id, String tag, String token) async {
    FormData formData;
    formData = FormData.fromMap({AppConstant.playlist_name: tag});

    Response<String> response;
    try {
      response = await dio.post(
        AppConstant.BaseUrl + AppConstant.API_CREATE_PLAYLIST,
        data: formData,
        options: Options(headers: createAuthHeaders(token)),
      );

      await TokenExpirationHandler().checkAndHandleResponse(response);
    } on DioException catch (e) {
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      // Return early on token expiry or network error
      return;
    }

    try {
      if (response.statusCode == 200) {
        // Optionally parse response for debug or future use
        json.decode(response.data.toString());
      }
    } catch (error) {}
  }

  Future<void> createPlaylistWithContext(
    String id,
    String tag,
    String token,
    BuildContext context,
  ) async {
    FormData formData = FormData.fromMap({AppConstant.playlist_name: tag});

    final response = await post<String>(
      AppConstant.BaseUrl + AppConstant.API_CREATE_PLAYLIST,
      data: formData,
      options: Options(headers: createAuthHeaders(token)),
      context: context,
    );

    try {
      if (response.statusCode == 200) {
        json.decode(response.data.toString());
      }
    } catch (error) {}
  }

  Future<Map<String, dynamic>> addMusicPlaylist(
    String MusId,
    String PlayListId,
    String token,
  ) async {
    FormData formData;
    formData = FormData.fromMap({
      AppConstant.music_id: MusId,
      AppConstant.playlist_id: PlayListId,
    });

    Response<String> response;
    try {
      response = await dio.post(
        AppConstant.BaseUrl + AppConstant.API_ADD_PLAYLIST_MUSIC,
        data: formData,
        options: Options(headers: createAuthHeaders(token)),
      );

      await TokenExpirationHandler().checkAndHandleResponse(response);
    } on DioException catch (e) {
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      return {'status': false, 'msg': 'Something went wrong'};
    }

    try {
      final Map<String, dynamic> parsed = json.decode(response.data.toString());
      return parsed;
    } catch (error) {
      return {'status': false, 'msg': 'Something went wrong'};
    }
  }

  Future<Map<String, dynamic>> addMusicPlaylistWithContext(
    String MusId,
    String PlayListId,
    String token,
    BuildContext context,
  ) async {
    FormData formData = FormData.fromMap({
      AppConstant.music_id: MusId,
      AppConstant.playlist_id: PlayListId,
    });

    final response = await post<String>(
      AppConstant.BaseUrl + AppConstant.API_ADD_PLAYLIST_MUSIC,
      data: formData,
      options: Options(headers: createAuthHeaders(token)),
      context: context,
    );

    try {
      final Map<String, dynamic> parsed = json.decode(response.data.toString());
      return parsed;
    } catch (error) {
      return {'status': false, 'msg': 'Something went wrong'};
    }
  }

  Future<void> updatePlaylist(
    String playlistname,
    String PlayListId,
    String token,
  ) async {
    FormData formData;
    formData = FormData.fromMap({
      AppConstant.playlist_name: playlistname,
      AppConstant.playlist_id: PlayListId,
    });

    Response<String> response;
    try {
      response = await dio.post(
        AppConstant.BaseUrl + AppConstant.API_UPDATE_PLAYLIST_NAME,
        data: formData,
        options: Options(headers: createAuthHeaders(token)),
      );

      await TokenExpirationHandler().checkAndHandleResponse(response);
    } on DioException catch (e) {
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      // Return early on token expiry or network error
      return;
    }

    try {
      if (response.statusCode == 200) {
        json.decode(response.data.toString());
      }
    } catch (error) {
      Fluttertoast.showToast(
        msg: 'Something went wrong!! Restart app',
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 1,
        backgroundColor: appColors().black,
        textColor: appColors().colorBackground,
        fontSize: 16.sp,
      );
    }
  }

  Future<void> updatePlaylistWithContext(
    String playlistname,
    String PlayListId,
    String token,
    BuildContext context,
  ) async {
    FormData formData = FormData.fromMap({
      AppConstant.playlist_name: playlistname,
      AppConstant.playlist_id: PlayListId,
    });

    final response = await post<String>(
      AppConstant.BaseUrl + AppConstant.API_UPDATE_PLAYLIST_NAME,
      data: formData,
      options: Options(headers: createAuthHeaders(token)),
      context: context,
    );

    try {
      if (response.statusCode == 200) {
        json.decode(response.data.toString());
      }
    } catch (error) {
      Fluttertoast.showToast(
        msg: 'Something went wrong!! Restart app',
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 1,
        backgroundColor: appColors().black,
        textColor: appColors().colorBackground,
        fontSize: 16.sp,
      );
    }
  }

  Future<void> removeMusicFromPlaylist(
    String musicId,
    String PlayListId,
    String token,
  ) async {
    FormData formData;
    formData = FormData.fromMap({
      AppConstant.playlist_id: PlayListId,
      AppConstant.music_id: musicId,
    });

    Response<String> response;
    try {
      response = await dio.post(
        AppConstant.BaseUrl + AppConstant.API_REMOVE_PLAYLIST_MUSIC,
        data: formData,
        options: Options(headers: createAuthHeaders(token)),
      );

      await TokenExpirationHandler().checkAndHandleResponse(response);
    } on DioException catch (e) {
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      // Return early on token expiry or network error
      return;
    }

    try {
      if (response.statusCode == 200) {
        json.decode(response.data.toString());
      }
    } catch (error) {}
  }

  Future<void> removeMusicFromPlaylistWithContext(
    String musicId,
    String PlayListId,
    String token,
    BuildContext context,
  ) async {
    FormData formData = FormData.fromMap({
      AppConstant.playlist_id: PlayListId,
      AppConstant.music_id: musicId,
    });

    final response = await post<String>(
      AppConstant.BaseUrl + AppConstant.API_REMOVE_PLAYLIST_MUSIC,
      data: formData,
      options: Options(headers: createAuthHeaders(token)),
      context: context,
    );

    try {
      if (response.statusCode == 200) {
        json.decode(response.data.toString());
      }
    } catch (error) {}
  }

  Future<Map<String, dynamic>> removePlaylist(
    String PlayListId,
    String token,
  ) async {
    FormData formData = FormData.fromMap({AppConstant.playlist_id: PlayListId});

    try {
      Response<String> response = await dio.post(
        AppConstant.BaseUrl + AppConstant.API_DELETE_PLAYLIST,
        data: formData,
        options: Options(headers: createAuthHeaders(token)),
      );

      await TokenExpirationHandler().checkAndHandleResponse(response);

      // Parse and return the backend JSON response so callers can act on status/msg
      final Map<String, dynamic> parsed = json.decode(response.data.toString());
      return parsed;
    } on DioException catch (e) {
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      return {'status': false, 'msg': 'Something went wrong'};
    } catch (error) {
      return {'status': false, 'msg': 'Something went wrong'};
    }
  }

  Future<Map<String, dynamic>> removePlaylistWithContext(
    String PlayListId,
    String token,
    BuildContext context,
  ) async {
    FormData formData = FormData.fromMap({AppConstant.playlist_id: PlayListId});

    final response = await post<String>(
      AppConstant.BaseUrl + AppConstant.API_DELETE_PLAYLIST,
      data: formData,
      options: Options(headers: createAuthHeaders(token)),
      context: context,
    );

    final Map<String, dynamic> parsed = json.decode(response.data.toString());
    return parsed;
  }
}
