import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Presenter/DownloadPresenter.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/utils/SharedPref.dart';

/// Repository for managing download-related API calls
class DownloadRepository {
  static final DownloadRepository _instance = DownloadRepository._internal();
  factory DownloadRepository() => _instance;
  DownloadRepository._internal();

  final DownloadPresenter _downloadPresenter = DownloadPresenter();
  final SharedPref _sharedPref = SharedPref();

  /// Get the list of downloaded music from the server
  Future<ModelMusicList?> getDownloadedMusicList() async {
    try {
      final token = await _sharedPref.getToken();
      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      developer.log(
        'Fetching downloaded music list from server',
        name: 'DownloadRepository',
      );
      // Use global navigatorKey.currentContext as a fallback if repository is
      // called outside of a widget. If null, fall back to legacy presenter.
      final BuildContext? context = navigatorKey.currentContext;
      final result =
          context != null
              ? await _downloadPresenter.getDownload(context, token)
              : await _downloadPresenter.getDownloadLegacy(token);

      developer.log(
        'Successfully fetched ${result.data.length} downloaded tracks',
        name: 'DownloadRepository',
      );
      return result;
    } catch (e) {
      developer.log(
        'Failed to get downloaded music list: $e',
        name: 'DownloadRepository',
      );
      return null;
    }
  }

  /// Add a track to the user's download list on the server
  Future<bool> addTrackToDownloads(String musicId) async {
    try {
      final token = await _sharedPref.getToken();
      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      developer.log(
        'Adding track $musicId to downloads',
        name: 'DownloadRepository',
      );
      final BuildContext? context = navigatorKey.currentContext;
      if (context != null) {
        await _downloadPresenter.addRemoveFromDownload(
          context,
          musicId,
          token,
          tag: 'add',
        );
      } else {
        await _downloadPresenter.addRemoveFromDownloadLegacy(
          musicId,
          token,
          tag: 'add',
        );
      }

      developer.log(
        'Successfully added track $musicId to downloads',
        name: 'DownloadRepository',
      );
      return true;
    } catch (e) {
      developer.log(
        'Failed to add track $musicId to downloads: $e',
        name: 'DownloadRepository',
      );
      return false;
    }
  }

  /// Remove a track from the user's download list on the server
  Future<bool> removeTrackFromDownloads(String musicId) async {
    try {
      final token = await _sharedPref.getToken();
      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      developer.log(
        'Removing track $musicId from downloads',
        name: 'DownloadRepository',
      );
      final BuildContext? context = navigatorKey.currentContext;
      if (context != null) {
        await _downloadPresenter.addRemoveFromDownload(
          context,
          musicId,
          token,
          tag: 'remove',
        );
      } else {
        await _downloadPresenter.addRemoveFromDownloadLegacy(
          musicId,
          token,
          tag: 'remove',
        );
      }

      developer.log(
        'Successfully removed track $musicId from downloads',
        name: 'DownloadRepository',
      );
      return true;
    } catch (e) {
      developer.log(
        'Failed to remove track $musicId from downloads: $e',
        name: 'DownloadRepository',
      );
      return false;
    }
  }

  /// Toggle a track's download status on the server
  Future<bool> toggleTrackDownload(
    String musicId,
    bool isCurrentlyDownloaded,
  ) async {
    if (isCurrentlyDownloaded) {
      return await removeTrackFromDownloads(musicId);
    } else {
      return await addTrackToDownloads(musicId);
    }
  }
}
