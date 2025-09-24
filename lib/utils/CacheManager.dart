import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/services/image_url_normalizer.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CacheManager {
  static const String MUSIC_CATEGORIES_CACHE_KEY = 'music_categories_cache';
  static const String RECENT_SEARCHES_CACHE_KEY = 'recent_searches_cache';
  static const String CACHE_STATE_KEY = 'cache_state_key';
  static const String IMAGE_CACHE_KEY = 'image_cache_key';
  static const Duration DEFAULT_CACHE_DURATION = Duration(hours: 12);
  static const Duration RECENT_SEARCHES_DURATION = Duration(hours: 240);
  static const Duration IMAGE_CACHE_DURATION = Duration(days: 7);

  // Track if fresh data is currently being loaded
  static bool _isFreshDataLoading = false;
  static bool get isFreshDataLoading => _isFreshDataLoading;

  // Track if cache is valid and fresh
  static Future<bool> isCacheValid(String key, {Duration? customExpiry}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString(key);

      if (cacheString == null) return false;

      final cacheData = json.decode(cacheString);
      final timestamp = cacheData['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiry = customExpiry ?? DEFAULT_CACHE_DURATION;

      return (now - timestamp) <= expiry.inMilliseconds;
    } catch (e) {
      print('Error checking cache validity: $e');
      return false;
    }
  }

  // Set loading state
  static void setFreshDataLoading(bool loading) {
    _isFreshDataLoading = loading;
  }

  // Save data to cache with timestamp
  static Future<bool> saveToCache(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert data to JSON string if it's not already
      String jsonData;
      if (data is String) {
        jsonData = data;
      } else {
        jsonData = json.encode(data);
      }

      final cacheData = {
        'data': jsonData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'version': '1.0',
      };

      final success = await prefs.setString(key, json.encode(cacheData));

      // Update cache state
      if (success && key == MUSIC_CATEGORIES_CACHE_KEY) {
        await _updateCacheState(key, true);
      }

      return success;
    } catch (e) {
      print('Error saving to cache: $e');
      return false;
    }
  }

  // Get data from cache if not expired
  static Future<Map<String, dynamic>?> getFromCache(
    String key, {
    Duration expiry = DEFAULT_CACHE_DURATION,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString(key);

      if (cacheString == null) return null;

      final cacheData = json.decode(cacheString);
      final timestamp = cacheData['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Check if cache is expired
      if (now - timestamp > expiry.inMilliseconds) {
        await clearCache(key);
        await _updateCacheState(key, false);
        return null;
      }

      // Return the cache data structure with proper data field
      return {
        'data': cacheData['data'], // This is already a JSON string
        'timestamp': timestamp,
        'version': cacheData['version'] ?? '1.0',
      };
    } catch (e) {
      print('Error getting from cache: $e');
      return null;
    }
  }

  // Update cache state tracking
  static Future<void> _updateCacheState(String key, bool isValid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateData = {
        'key': key,
        'isValid': isValid,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString('${CACHE_STATE_KEY}_$key', json.encode(stateData));
    } catch (e) {
      print('Error updating cache state: $e');
    }
  }

  // Check if we have valid cached data without loading it
  static Future<bool> hasCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateString = prefs.getString('${CACHE_STATE_KEY}_$key');

      if (stateString == null) return await isCacheValid(key);

      final stateData = json.decode(stateString);
      return stateData['isValid'] == true && await isCacheValid(key);
    } catch (e) {
      return await isCacheValid(key);
    }
  }

  // Save image cache metadata
  static Future<bool> saveImageCacheInfo(
    String imageUrl,
    String localPath,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingCache = prefs.getString(IMAGE_CACHE_KEY);

      Map<String, dynamic> imageCache = {};
      if (existingCache != null) {
        imageCache = json.decode(existingCache);
      }

      imageCache[imageUrl] = {
        'localPath': localPath,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      return await prefs.setString(IMAGE_CACHE_KEY, json.encode(imageCache));
    } catch (e) {
      print('Error saving image cache info: $e');
      return false;
    }
  }

  // Get cached image path
  static Future<String?> getCachedImagePath(String imageUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString(IMAGE_CACHE_KEY);

      if (cacheString == null) return null;

      final imageCache = json.decode(cacheString);
      final imageData = imageCache[imageUrl];

      if (imageData == null) return null;

      final timestamp = imageData['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Check if image cache is expired
      if (now - timestamp > IMAGE_CACHE_DURATION.inMilliseconds) {
        // Remove expired entry
        imageCache.remove(imageUrl);
        await prefs.setString(IMAGE_CACHE_KEY, json.encode(imageCache));
        return null;
      }

      return imageData['localPath'];
    } catch (e) {
      print('Error getting cached image path: $e');
      return null;
    }
  }

  // Clear specific cache
  static Future<bool> clearCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.remove(key);

      if (success) {
        await _updateCacheState(key, false);
      }

      return success;
    } catch (e) {
      print('Error clearing cache: $e');
      return false;
    }
  }

  // Force refresh cache - mark as invalid to trigger fresh load
  static Future<bool> forceRefreshCache(String key) async {
    try {
      await clearCache(key);
      await _updateCacheState(key, false);
      return true;
    } catch (e) {
      print('Error forcing cache refresh: $e');
      return false;
    }
  }

  // Clear all cache
  static Future<bool> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Preserve remember me data before clearing
      bool? rememberMe = prefs.getBool('remember_me');
      String? rememberedEmail = prefs.getString('remembered_email');
      String? rememberedPassword = prefs.getString('remembered_password');

      // Clear all data
      await prefs.clear();

      // Restore remember me data if it existed
      if (rememberMe != null) {
        await prefs.setBool('remember_me', rememberMe);
      }
      if (rememberedEmail != null) {
        await prefs.setString('remembered_email', rememberedEmail);
      }
      if (rememberedPassword != null) {
        await prefs.setString('remembered_password', rememberedPassword);
      }

      print("DEBUG CacheManager: Cache cleared, remember me data preserved");
      return true;
    } catch (e) {
      print('Error clearing all cache: $e');
      return false;
    }
  }

  // Clear all cache including in-memory image cache
  static Future<bool> clearAllCacheIncludingImages() async {
    try {
      // Clear shared preferences cache
      bool result = await clearAllCache();

      // Clear in-memory image cache
      final imageCache = PaintingBinding.instance.imageCache;
      imageCache.clear();

      // Clear cached network images
      try {
        // This will clear CachedNetworkImage cache
        await CachedNetworkImage.evictFromCache('');
      } catch (e) {
        print('Warning: Could not clear CachedNetworkImage cache: $e');
      }

      print("DEBUG CacheManager: All cache cleared including images");
      return result;
    } catch (e) {
      print('Error clearing all cache including images: $e');
      return false;
    }
  }

  // Save recent search (song that was tapped) - Updated to include complete audio URL
  static Future<bool> saveRecentSearch(
    Map<String, dynamic> songData, {
    String? imagePath,
    String? audioPath,
  }) async {
    try {
      // Get existing recent searches
      List<Map<String, dynamic>> recentSearches = await getRecentSearches();

      // Remove if already exists (to avoid duplicates and move to top)
      recentSearches.removeWhere((item) => item['id'] == songData['id']);

      // Ensure we have the complete audio URL
      String completeAudioUrl = songData['audio'] ?? '';

      print(
        '[DEBUG] CacheManager: Saving recent search for ${songData['audio_title']}',
      );
      print('[DEBUG] CacheManager: Original audio URL: $completeAudioUrl');

      // If audio URL is not complete, try to reconstruct it
      if (completeAudioUrl.isNotEmpty && !completeAudioUrl.startsWith('http')) {
  const baseUrl = 'http://143.244.213.49/jainverse-staging/public/';
        if (audioPath != null && audioPath.isNotEmpty) {
          completeAudioUrl = '$baseUrl$audioPath$completeAudioUrl';
        } else {
          completeAudioUrl = '$baseUrl$completeAudioUrl';
        }
        print(
          '[DEBUG] CacheManager: Reconstructed audio URL: $completeAudioUrl',
        );
      }

      // Add to beginning of list with complete data including full audio URL
      recentSearches.insert(0, {
        ...songData,
        'audio': completeAudioUrl, // Store the complete audio URL
        'imagePath': imagePath ?? '', // Store the base image path
        'audioPath': audioPath ?? '', // Store the base audio path
        'artists_name':
            songData['artists_name'] ?? '', // Ensure artist name is preserved
        'searchedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Keep only last 50 searches
      if (recentSearches.length > 50) {
        recentSearches = recentSearches.take(50).toList();
      }

      return await saveToCache(RECENT_SEARCHES_CACHE_KEY, recentSearches);
    } catch (e) {
      print('Error saving recent search: $e');
      return false;
    }
  }

  // Get recent searches
  static Future<List<Map<String, dynamic>>> getRecentSearches() async {
    try {
      final cachedData = await getFromCache(
        RECENT_SEARCHES_CACHE_KEY,
        expiry: RECENT_SEARCHES_DURATION,
      );

      if (cachedData != null && cachedData['data'] != null) {
        final List<dynamic> data = json.decode(cachedData['data']);
        return data.cast<Map<String, dynamic>>();
      }

      return [];
    } catch (e) {
      print('Error getting recent searches: $e');
      return [];
    }
  }

  // Clear recent searches
  static Future<bool> clearRecentSearches() async {
    try {
      return await clearCache(RECENT_SEARCHES_CACHE_KEY);
    } catch (e) {
      print('Error clearing recent searches: $e');
      return false;
    }
  }

  // Remove specific recent search
  static Future<bool> removeRecentSearch(String songId) async {
    try {
      List<Map<String, dynamic>> recentSearches = await getRecentSearches();
      recentSearches.removeWhere((item) => item['id'].toString() == songId);
      return await saveToCache(RECENT_SEARCHES_CACHE_KEY, recentSearches);
    } catch (e) {
      print('Error removing recent search: $e');
      return false;
    }
  }

  // Add this method to convert cached data to DataMusic object
  static DataMusic convertToDataMusic(Map<String, dynamic> item) {
    // Get artist name from multiple possible sources
    String artistName = getArtistNameFromCache(item);

    // Get complete audio URL
    String audioUrl = item['audio'] ?? '';

    print(
      '[DEBUG] CacheManager: Converting to DataMusic for ${item['audio_title']}',
    );
    print('[DEBUG] CacheManager: Cached audio URL: $audioUrl');

    // If audio URL is not complete, try to reconstruct it
    if (audioUrl.isNotEmpty && !audioUrl.startsWith('http')) {
  const baseUrl = 'http://143.244.213.49/jainverse-staging/public/';
      final audioPath = item['audioPath'] ?? '';

      if (audioPath.isNotEmpty) {
        // Make sure audioPath ends with / for correct concatenation
        String cleanAudioPath =
            audioPath.endsWith('/') ? audioPath : '$audioPath/';
        audioUrl = '$baseUrl$cleanAudioPath$audioUrl';
      } else {
        // Fallback construction for legacy cached data - use proper audio path
        audioUrl = '${baseUrl}images/audio/$audioUrl';
      }
      print('[DEBUG] CacheManager: Reconstructed audio URL: $audioUrl');
    } else if (audioUrl.isEmpty) {
      // Handle empty audio URL case
      print(
        '[WARNING] CacheManager: Empty audio URL for ${item['audio_title']}',
      );
      audioUrl = '';
    }

    return DataMusic(
      int.tryParse(item['id'].toString()) ?? 0,
      item['image'] ?? '',
      audioUrl, // Use the complete audio URL
      item['audio_duration'] ?? '',
      item['audio_title'] ?? '',
      item['audio_slug'] ?? '',
      int.tryParse(item['audio_genre_id'].toString()) ?? 0,
      item['artist_id'] ?? '',
      artistName, // Use the extracted artist name
      item['audio_language'] ?? '',
      int.tryParse(item['listening_count'].toString()) ?? 0,
      int.tryParse(item['is_featured'].toString()) ?? 0,
      int.tryParse(item['is_trending'].toString()) ?? 0,
      item['created_at'] ?? '',
      int.tryParse(item['is_recommended'].toString()) ?? 0,
      item['favourite'] ?? '0',
      item['download_price'] ?? '',
      item['lyrics'] ?? '',
    );
  }

  // Helper method to get full image URL from cached data with improved URL construction
  static String getFullImageUrl(Map<String, dynamic> item) {
    final imagePath = item['imagePath'] ?? '';
    final image = item['image'] ?? '';

    if (image.isEmpty) {
      return '';
    }

    // If image is already a complete URL, return it
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return image;
    }

    // Construct URL using ImageUrlNormalizer for consistency
    try {
      // Use the ImageUrlNormalizer for consistent URL construction
      final normalizedUrl = ImageUrlNormalizer.normalizeImageUrl(
        imageFileName: image,
        pathImage: imagePath.isNotEmpty ? imagePath : null,
      );
      return normalizedUrl;
    } catch (e) {
      // Fallback to simple concatenation if normalizer fails
      if (imagePath.isNotEmpty && image.isNotEmpty) {
        return AppConstant.ImageUrl + imagePath + image;
      } else if (image.isNotEmpty) {
        return AppConstant.ImageUrl + image;
      }
      return '';
    }
  }

  // Update cached music data to include artist names if missing
  static Future<bool> updateCachedMusicWithArtistNames(
    String key,
    Map<String, dynamic> updatedData,
  ) async {
    try {
      // Get existing cache
      final existingCache = await getFromCache(key);

      if (existingCache == null) {
        // No existing cache, save new data
        return await saveToCache(key, updatedData);
      }

      // Parse existing data
      final existingDataJson = json.decode(existingCache['data']);

      // Update with new artist information while preserving other data
      final mergedData = _mergeMusicData(existingDataJson, updatedData);

      // Save updated cache
      return await saveToCache(key, mergedData);
    } catch (e) {
      print('Error updating cached music with artist names: $e');
      return false;
    }
  }

  // Helper method to merge music data while preserving artist names
  static Map<String, dynamic> _mergeMusicData(
    Map<String, dynamic> existingData,
    Map<String, dynamic> newData,
  ) {
    try {
      // Create a copy of existing data
      final mergedData = Map<String, dynamic>.from(existingData);

      // Update data array if present
      if (newData['data'] != null && existingData['data'] != null) {
        final List<dynamic> existingItems = existingData['data'];
        final List<dynamic> newItems = newData['data'];

        // Create a map for quick lookup of new items by ID
        final Map<String, dynamic> newItemsMap = {};
        for (var item in newItems) {
          if (item['id'] != null) {
            newItemsMap[item['id'].toString()] = item;
          }
        }

        // Update existing items with new artist information
        for (int i = 0; i < existingItems.length; i++) {
          final existingItem = existingItems[i];
          final itemId = existingItem['id']?.toString();

          if (itemId != null && newItemsMap.containsKey(itemId)) {
            final newItem = newItemsMap[itemId];

            // Merge item data, prioritizing new artist information
            existingItems[i] = {
              ...existingItem,
              'artists_name':
                  newItem['artists_name'] ?? existingItem['artists_name'],
              'artist': newItem['artist'] ?? existingItem['artist'],
            };
          }
        }

        mergedData['data'] = existingItems;
      }

      return mergedData;
    } catch (e) {
      print('Error merging music data: $e');
      return newData; // Return new data as fallback
    }
  }

  // Get artist name from cached item data
  static String getArtistNameFromCache(Map<String, dynamic> item) {
    // Try multiple possible keys for artist name
    return item['artists_name'] ??
        item['artist']?['name'] ??
        item['artistName'] ??
        '';
  }

  // Save music categories cache with enhanced artist data
  static Future<bool> saveMusicCategoriesCache(
    Map<String, dynamic> musicData,
  ) async {
    try {
      // Ensure all music items have proper artist name fields
      if (musicData['data'] != null) {
        final List<dynamic> categories = musicData['data'];

        for (var category in categories) {
          if (category['sub_category'] != null) {
            final List<dynamic> subCategories = category['sub_category'];

            for (var item in subCategories) {
              // Normalize artist name field
              if (item['artist'] != null && item['artist']['name'] != null) {
                item['artists_name'] = item['artist']['name'];
              } else if (item['artists_name'] == null) {
                item['artists_name'] = '';
              }
            }
          }
        }
      }

      return await saveToCache(MUSIC_CATEGORIES_CACHE_KEY, musicData);
    } catch (e) {
      print('Error saving music categories cache: $e');
      return false;
    }
  }

  // Get music categories cache with proper artist name handling
  static Future<Map<String, dynamic>?> getMusicCategoriesCache() async {
    try {
      final cachedData = await getFromCache(MUSIC_CATEGORIES_CACHE_KEY);

      if (cachedData != null && cachedData['data'] != null) {
        final musicData = json.decode(cachedData['data']);

        // Ensure artist names are properly populated
        if (musicData['data'] != null) {
          final List<dynamic> categories = musicData['data'];

          for (var category in categories) {
            if (category['sub_category'] != null) {
              final List<dynamic> subCategories = category['sub_category'];

              for (var item in subCategories) {
                // Ensure artists_name field exists
                if (item['artists_name'] == null) {
                  item['artists_name'] = item['artist']?['name'] ?? '';
                }
              }
            }
          }
        }

        return musicData;
      }

      return null;
    } catch (e) {
      print('Error getting music categories cache: $e');
      return null;
    }
  }
}
