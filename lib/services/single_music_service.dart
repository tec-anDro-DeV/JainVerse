import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/AppConstant.dart';

/// API response model for single music
/// Updated to match the new API response structure with correct field names
class SingleMusicResponse {
  final int id;
  final String audio;
  final String audioTitle;
  final String audioSlug;
  final String artistsName;
  final String artistId;
  final String audioDuration;
  final String image;
  final String bannerImage;
  final String shareUri;
  final int isAws;
  final String status;

  SingleMusicResponse({
    required this.id,
    required this.audio,
    required this.audioTitle,
    required this.audioSlug,
    required this.artistsName,
    required this.artistId,
    required this.audioDuration,
    required this.image,
    required this.bannerImage,
    required this.shareUri,
    required this.isAws,
    required this.status,
  });

  factory SingleMusicResponse.fromJson(Map<String, dynamic> json) {
    return SingleMusicResponse(
      id: json['id'] ?? 0,
      audio: json['audio'] ?? '',
      audioTitle: json['audio_title'] ?? '',
      audioSlug: json['audio_slug'] ?? '',
      artistsName: json['artists_name'] ?? '',
      artistId: json['artist_id'] ?? '',
      audioDuration: json['audio_duration'] ?? '3:00',
      image: json['image'] ?? '',
      bannerImage: json['banner_image'] ?? '',
      shareUri: json['share_uri'] ?? '',
      isAws: json['is_aws'] ?? 0,
      status: json['status'] ?? '',
    );
  }
}

/// Service to fetch single music data from the API
/// Used for Play Next and Add to Queue functionality to get complete song details
class SingleMusicService {
  static final SingleMusicService _instance = SingleMusicService._internal();
  factory SingleMusicService() => _instance;
  SingleMusicService._internal();

  final SharedPref _sharedPref = SharedPref();

  /// Fetch single music data by music ID
  Future<DataMusic?> fetchSingleMusic(String musicId) async {
    try {
      developer.log(
        '[SingleMusicService] Fetching single music data for ID: $musicId',
        name: 'SingleMusicService',
      );

      // Get user token
      final token = await _sharedPref.getToken() ?? '';
      if (token.isEmpty) {
        developer.log(
          '[SingleMusicService] No auth token available',
          name: 'SingleMusicService',
        );
        return null;
      }

      // Prepare API request
      final url = Uri.parse('${AppConstant.BaseUrl}single_music');
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

      // Create multipart request
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(headers);
      request.fields['musicid'] = musicId;

      developer.log(
        '[SingleMusicService] Making API request to: $url',
        name: 'SingleMusicService',
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      developer.log(
        '[SingleMusicService] API response status: ${response.statusCode}',
        name: 'SingleMusicService',
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);

        if (jsonList.isNotEmpty) {
          final singleMusicData = SingleMusicResponse.fromJson(jsonList[0]);

          if (singleMusicData.status == 'success') {
            developer.log(
              '[SingleMusicService] ✅ Successfully fetched music: ${singleMusicData.audioTitle}',
              name: 'SingleMusicService',
            );

            // Convert to DataMusic object
            return _convertToDataMusic(singleMusicData);
          } else {
            developer.log(
              '[SingleMusicService] ❌ API returned failure status',
              name: 'SingleMusicService',
            );
          }
        } else {
          developer.log(
            '[SingleMusicService] ❌ Empty response from API',
            name: 'SingleMusicService',
          );
        }
      } else {
        developer.log(
          '[SingleMusicService] ❌ API request failed with status: ${response.statusCode}',
          name: 'SingleMusicService',
        );
        developer.log(
          '[SingleMusicService] Response body: ${response.body}',
          name: 'SingleMusicService',
        );
      }
    } catch (e) {
      developer.log(
        '[SingleMusicService] ❌ Exception occurred: $e',
        name: 'SingleMusicService',
        error: e,
      );
    }

    return null;
  }

  /// Convert SingleMusicResponse to DataMusic object
  DataMusic _convertToDataMusic(SingleMusicResponse response) {
    // Use the actual duration from API, fallback to default if empty
    final duration =
        response.audioDuration.isNotEmpty ? response.audioDuration : '3:00';

    return DataMusic(
      response.id,
      response.image, // image
      response.audio, // audio (full URL)
      duration, // audio_duration (now from API)
      response.audioTitle, // audio_title
      response.audioSlug.isNotEmpty
          ? response.audioSlug
          : _generateSlug(
            response.audioTitle,
          ), // audio_slug (use from API or generate)
      0, // audio_genre_id (not provided by API)
      response.artistId, // artist_id (now from API)
      response.artistsName, // artists_name
      '', // audio_language (not provided by API)
      0, // listening_count (not provided by API)
      0, // is_featured (not provided by API)
      0, // is_trending (not provided by API)
      '', // created_at (not provided by API)
      0, // is_recommended (not provided by API)
      '0', // favourite (default to not favorite)
      '', // download_price (not provided by API)
      '', // lyrics (not provided by API)
    );
  }

  /// Generate slug from audio title
  String _generateSlug(String audioTitle) {
    return audioTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .trim();
  }

  /// Fetch multiple songs by IDs (batch operation)
  Future<List<DataMusic>> fetchMultipleSongs(List<String> musicIds) async {
    final List<DataMusic> results = [];

    // Fetch songs sequentially to avoid rate limiting
    for (final musicId in musicIds) {
      final music = await fetchSingleMusic(musicId);
      if (music != null) {
        results.add(music);
      }

      // Small delay to prevent overwhelming the API
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return results;
  }

  /// Check if the service is available (has valid token)
  Future<bool> isServiceAvailable() async {
    final token = await _sharedPref.getToken() ?? '';
    return token.isNotEmpty;
  }

  /// Get enhanced song information with all available metadata
  /// This method provides additional logging and validation for debugging
  Future<Map<String, dynamic>?> getEnhancedSongInfo(String musicId) async {
    try {
      final token = await _sharedPref.getToken() ?? '';
      if (token.isEmpty) {
        developer.log(
          '[SingleMusicService] No auth token for enhanced info request',
          name: 'SingleMusicService',
        );
        return null;
      }

      final url = Uri.parse('${AppConstant.BaseUrl}single_music');
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(headers);
      request.fields['musicid'] = musicId;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        if (jsonList.isNotEmpty) {
          final songData = jsonList[0] as Map<String, dynamic>;

          developer.log(
            '[SingleMusicService] Enhanced info - Title: ${songData['audio_title']}, Artist: ${songData['artists_name']}, Duration: ${songData['audio_duration']}',
            name: 'SingleMusicService',
          );

          return songData;
        }
      }

      return null;
    } catch (e) {
      developer.log(
        '[SingleMusicService] Error getting enhanced song info: $e',
        name: 'SingleMusicService',
        error: e,
      );
      return null;
    }
  }
}
