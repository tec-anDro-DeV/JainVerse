import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Model/ModelStationResponse.dart';
import 'package:jainverse/Presenter/StationPresenter.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/managers/music_manager.dart';

/// Service for managing station creation and queue replacement
class StationService {
  static final StationService _instance = StationService._internal();
  factory StationService() => _instance;
  StationService._internal();

  final StationPresenter _stationPresenter = StationPresenter();
  final SharedPref _sharedPref = SharedPref();

  /// Create a station based on the current song and replace the queue
  /// while keeping the current song playing
  Future<bool> createStation(DataMusic currentSong) async {
    try {
      final token = await _sharedPref.getToken();
      if (token.isEmpty) {
        if (kDebugMode) {
          print('[StationService] User not logged in');
        }
        return false;
      }

      if (kDebugMode) {
        print(
          '[StationService] Creating station for song: ${currentSong.audio_title}',
        );
      }

      // Call the API to get similar songs
      final ModelStationResponse response = await _stationPresenter
          .createStation(currentSong.id.toString(), token);

      if (!response.status || response.data.isEmpty) {
        if (kDebugMode) {
          print(
            '[StationService] Failed to create station or no similar songs found',
          );
        }
        return false;
      }

      if (kDebugMode) {
        print(
          '[StationService] Station created with ${response.data.length} similar songs',
        );
      }

      // Create the new station queue
      // Keep the current song at the beginning, then add similar songs
      final List<DataMusic> stationQueue = [currentSong, ...response.data];

      // Use MusicManager to replace the queue while keeping current song playing
      await MusicManager().replaceQueueWithStation(
        stationSongs: stationQueue,
        currentSong: currentSong,
        pathImage:
            response.imagePath.isNotEmpty
                ? response.imagePath
                : 'images/audio/thumb/',
        audioPath:
            response.audioPath.isNotEmpty
                ? response.audioPath
                : 'images/audio/',
      );

      if (kDebugMode) {
        print('[StationService] Station queue successfully replaced');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[StationService] Error creating station: $e');
      }
      developer.log(
        '[ERROR][StationService] Failed to create station: $e',
        name: 'StationService',
        error: e,
      );
      return false;
    }
  }

  /// Parse audio duration string like '4:48' to Duration object
  static Duration parseAudioDuration(String durationString) {
    try {
      final cleanDuration = durationString.trim().replaceAll('\n', '');
      final parts = cleanDuration.split(':');

      if (parts.length == 2) {
        // Format: MM:SS
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return Duration(minutes: minutes, seconds: seconds);
      } else if (parts.length == 3) {
        // Format: HH:MM:SS
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(double.parse(parts[2]).round().toString());
        return Duration(hours: hours, minutes: minutes, seconds: seconds);
      } else {
        // Invalid format, return default
        return const Duration(minutes: 3);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[StationService] Error parsing duration "$durationString": $e');
      }
      // Return default duration on error
      return const Duration(minutes: 3);
    }
  }
}
