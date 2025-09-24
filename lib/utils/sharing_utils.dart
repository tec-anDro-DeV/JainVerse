import 'package:share_plus/share_plus.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:flutter/widgets.dart';
import 'share_helper.dart';

///
/// This utility provides a consistent way to share songs across different screens
/// and contexts, reducing code duplication and ensuring consistent sharing behavior.
class SharingUtils {
  // Private constructor to prevent instantiation
  SharingUtils._();

  /// App constants for sharing
  static const String _appName = 'JainVerse';
  static const String _siteUrl = 'http://143.244.213.49/heargod-staging';

  /// Share a song using MediaItem (for music player contexts)
  ///
  /// [mediaItem] - The MediaItem containing song information
  /// [subject] - Optional subject for the share (defaults to generated text)
  static Future<void> shareFromMediaItem(
    MediaItem mediaItem, {
    String? subject,
    BuildContext? context,
  }) async {
    try {
      // Extract audio ID from extras or use default sharing logic
      final audioId = mediaItem.extras?['audio_id'] ?? mediaItem.id;
      final slug = mediaItem.album ?? 'music';
      final title =
          mediaItem.title.isEmpty ? 'this amazing song' : mediaItem.title;
      final artist =
          mediaItem.artist?.isEmpty == true
              ? 'great artist'
              : (mediaItem.artist ?? 'great artist');

      await _performShare(
        audioId: audioId,
        slug: slug,
        title: title,
        artist: artist,
        subject: subject,
        context: context,
      );
    } catch (e) {
      print('Error sharing from MediaItem: $e');
      rethrow;
    }
  }

  /// Share a song using DataMusic model (for list contexts)
  ///
  /// [song] - The DataMusic object containing song information
  /// [subject] - Optional subject for the share (defaults to generated text)
  static Future<void> shareFromDataMusic(
    DataMusic song, {
    String? subject,
    BuildContext? context,
  }) async {
    try {
      final audioId = song.id.toString();
      final slug = song.audio_slug.isNotEmpty ? song.audio_slug : 'music';
      final title = song.audio_title;
      final artist = song.artists_name;

      await _performShare(
        audioId: audioId,
        slug: slug,
        title: title,
        artist: artist,
        subject: subject,
        context: context,
      );
    } catch (e) {
      print('Error sharing from DataMusic: $e');
      rethrow;
    }
  }

  /// Share a song using individual parameters
  ///
  /// [audioId] - The unique audio ID
  /// [slug] - The URL slug for the song
  /// [title] - The song title
  /// [artist] - The artist name
  /// [subject] - Optional subject for the share (defaults to generated text)
  static Future<void> shareWithParams({
    required String audioId,
    required String slug,
    required String title,
    required String artist,
    String? subject,
    BuildContext? context,
  }) async {
    try {
      await _performShare(
        audioId: audioId,
        slug: slug,
        title: title,
        artist: artist,
        subject: subject,
        context: context,
      );
    } catch (e) {
      print('Error sharing with params: $e');
      rethrow;
    }
  }

  /// Internal method to perform the actual sharing
  static Future<void> _performShare({
    required String audioId,
    required String slug,
    required String title,
    required String artist,
    String? subject,
    BuildContext? context,
  }) async {
    // Generate the share text
    final shareText = _generateShareText(
      title: title,
      artist: artist,
      audioId: audioId,
      slug: slug,
    );

    // Use provided subject or default to the share text
    final shareSubject = subject ?? shareText;

    // Perform the share
    final rect = computeSharePosition(context);
    if (rect != null) {
      await Share.share(
        shareText,
        subject: shareSubject,
        sharePositionOrigin: rect,
      );
    } else {
      await Share.share(shareText, subject: shareSubject);
    }
  }

  /// Generate the formatted share text
  static String _generateShareText({
    required String title,
    required String artist,
    required String audioId,
    required String slug,
  }) {
    return '"$title" by $artist. Check it out now on $_appName! 🎵\n\n$_siteUrl/audio/single/$audioId/$slug';
  }

  /// Get a formatted share text without sharing (for preview purposes)
  ///
  /// [title] - The song title
  /// [artist] - The artist name
  /// [audioId] - The unique audio ID
  /// [slug] - The URL slug for the song
  static String getShareText({
    required String title,
    required String artist,
    required String audioId,
    required String slug,
  }) {
    return _generateShareText(
      title: title,
      artist: artist,
      audioId: audioId,
      slug: slug,
    );
  }

  /// Validate if sharing is possible with given parameters
  ///
  /// Returns true if all required parameters are present and valid
  static bool canShare({String? audioId, String? title, String? artist}) {
    return audioId != null &&
        audioId.isNotEmpty &&
        title != null &&
        title.isNotEmpty &&
        artist != null &&
        artist.isNotEmpty;
  }

  /// Share from MediaItem with validation
  ///
  /// Returns true if sharing was successful, false if validation failed
  static Future<bool> shareFromMediaItemSafe(
    MediaItem? mediaItem, {
    String? subject,
    BuildContext? context,
  }) async {
    if (mediaItem == null) {
      print('Cannot share: MediaItem is null');
      return false;
    }

    final audioId = mediaItem.extras?['audio_id'] ?? mediaItem.id;
    if (!canShare(
      audioId: audioId,
      title: mediaItem.title,
      artist: mediaItem.artist,
    )) {
      print('Cannot share: Missing required parameters');
      return false;
    }

    try {
      await shareFromMediaItem(mediaItem, subject: subject, context: context);
      return true;
    } catch (e) {
      print('Failed to share: $e');
      return false;
    }
  }

  /// Share from DataMusic with validation
  ///
  /// Returns true if sharing was successful, false if validation failed
  static Future<bool> shareFromDataMusicSafe(
    DataMusic? song, {
    String? subject,
    BuildContext? context,
  }) async {
    if (song == null) {
      print('Cannot share: DataMusic is null');
      return false;
    }

    if (!canShare(
      audioId: song.id.toString(),
      title: song.audio_title,
      artist: song.artists_name,
    )) {
      print('Cannot share: Missing required parameters');
      return false;
    }

    try {
      await shareFromDataMusic(song, subject: subject, context: context);
      return true;
    } catch (e) {
      print('Failed to share: $e');
      return false;
    }
  }
}
