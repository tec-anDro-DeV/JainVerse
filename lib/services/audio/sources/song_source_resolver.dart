import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/controllers/download_controller.dart';
import 'package:jainverse/models/downloaded_music.dart';

import '../common/audio_constants.dart';
import '../common/audio_logger.dart';

/// Resolves the effective playback metadata (local vs remote audio/artwork)
/// for legacy [DataMusic] entries coming from playlists or stations.
class SongSourceResolver {
  SongSourceResolver({DownloadController? downloadController})
    : _downloadController = downloadController ?? DownloadController();

  final DownloadController _downloadController;

  Future<MediaItem> resolveDataMusic({
    required DataMusic music,
    required int queueIndex,
    required String contextType,
    String? contextId,
  }) async {
    final networkAudioUrl = _expandToFullUrl(music.audio);
    final actualAudioUrl = await _resolveActualAudioUrl(
      music.id.toString(),
      networkAudioUrl,
    );
    final imageUrl = await _resolveImageUrl(music);
    final duration =
        _parseDuration(music.audio_duration) ??
        AudioConstants.defaultSongDuration;

    final mediaExtras = <String, dynamic>{
      'audio_id': music.id.toString(),
      'actual_audio_url': actualAudioUrl,
      'network_audio_url': networkAudioUrl,
      'context_type': contextType,
      'context_id': contextId ?? '',
      'queue_index': queueIndex,
      'lyrics': music.lyrics,
      'favourite': music.favourite,
      'is_downloaded': actualAudioUrl.startsWith('file://'),
      'artist_id': music.artist_id,
      'artists_name': music.artists_name,
    };

    final itemId = '$networkAudioUrl?ctx=$contextType&idx=$queueIndex';

    return MediaItem(
      id: itemId,
      title: music.audio_title.isNotEmpty ? music.audio_title : 'Unknown Title',
      artist: music.artists_name.isNotEmpty
          ? music.artists_name
          : 'Unknown Artist',
      album: music.artists_name.isNotEmpty
          ? music.artists_name
          : 'Unknown Album',
      duration: duration,
      artUri: imageUrl.isNotEmpty ? Uri.tryParse(imageUrl) : null,
      extras: mediaExtras,
    );
  }

  String _expandToFullUrl(String rawPath) {
    if (rawPath.isEmpty) return rawPath;
    if (rawPath.startsWith('http') || rawPath.startsWith('file://')) {
      return rawPath;
    }
    final normalized = rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;
    return '${AudioConstants.basePublicUrl}$normalized';
  }

  Future<String> _resolveActualAudioUrl(
    String trackId,
    String networkAudioUrl,
  ) async {
    try {
      final localAudioPath = _downloadController.getLocalAudioPath(trackId);
      if (localAudioPath == null || localAudioPath.isEmpty) {
        AudioLogger.log('[Music] Using network audio for track $trackId');
        return networkAudioUrl;
      }

      final audioFile = File(localAudioPath);
      if (await audioFile.exists()) {
        final localUri = audioFile.uri.toString();
        AudioLogger.log('[Music] Using local audio for track $trackId');
        return localUri;
      }

      AudioLogger.log(
        '[WARN][SongSourceResolver] Local audio missing for $trackId, falling back to network',
      );
      await _downloadController.removeFromDownloads(trackId);
    } catch (error, stackTrace) {
      AudioLogger.log(
        '[ERROR][SongSourceResolver] Failed to resolve local audio for $trackId',
        error: error,
        stackTrace: stackTrace,
        isError: true,
      );
    }
    return networkAudioUrl;
  }

  Future<String> _resolveImageUrl(DataMusic music) async {
    try {
      final downloadedTrack = _findDownloadedTrack(music.id.toString());
      final localImagePath = downloadedTrack?.localImagePath;
      if (localImagePath != null && localImagePath.isNotEmpty) {
        final imageFile = File(localImagePath);
        if (await imageFile.exists()) {
          AudioLogger.log(
            '[Music] Using local artwork for ${music.audio_title}',
          );
          return Uri.file(localImagePath).toString();
        }
      }
    } catch (error) {
      AudioLogger.log(
        '[WARN][SongSourceResolver] Failed to check local artwork for ${music.audio_title}: $error',
      );
    }
    return _createSafeImageUrl(music.image);
  }

  DownloadedMusic? _findDownloadedTrack(String trackId) {
    try {
      return _downloadController.downloadedTracks.firstWhere(
        (track) => track.id == trackId && track.isDownloadComplete,
      );
    } catch (_) {
      return null;
    }
  }

  String _createSafeImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return AudioConstants.placeholderImageUrl;
    }

    if (imagePath.startsWith('file://')) {
      return imagePath;
    }

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      final sanitizedSite = AudioConstants.basePublicUrl.replaceAll('/', '');
      if (imagePath.contains(sanitizedSite)) {
        return imagePath;
      }
      return AudioConstants.placeholderImageUrl;
    }

    return '${AudioConstants.basePublicUrl}images/audio/thumb/$imagePath';
  }

  Duration? _parseDuration(String rawDuration) {
    final clean = rawDuration.replaceAll('\n', '').trim();
    if (clean.isEmpty) {
      return null;
    }

    try {
      if (RegExp(r'^\d+$').hasMatch(clean)) {
        return Duration(seconds: int.parse(clean));
      }

      final parts = clean.split(':');
      if (parts.length == 2) {
        return Duration(
          minutes: int.parse(parts[0]),
          seconds: int.parse(parts[1]),
        );
      }
      if (parts.length == 3) {
        return Duration(
          hours: int.parse(parts[0]),
          minutes: int.parse(parts[1]),
          seconds: int.parse(parts[2]),
        );
      }
    } catch (error) {
      AudioLogger.log(
        '[WARN][SongSourceResolver] Failed to parse duration "$clean": $error',
      );
    }
    return null;
  }
}
