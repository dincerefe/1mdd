import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Debug print helper - only prints in debug mode
void _log(String message) {
  if (kDebugMode) {
    print(message);
  }
}

/// Service for persistent video caching
/// Videos remain cached even when app is closed
class VideoCacheService {
  static final VideoCacheService _instance = VideoCacheService._internal();
  factory VideoCacheService() => _instance;
  VideoCacheService._internal();

  static const String _cacheKey = 'video_persistent_cache';
  static const int _maxCachedVideos = 10; // Keep up to 10 videos cached
  static const Duration _maxAge = Duration(days: 7); // Keep for 7 days
  
  /// Custom cache manager for videos with persistent storage
  static final CacheManager _cacheManager = CacheManager(
    Config(
      'video_cache',
      stalePeriod: _maxAge,
      maxNrOfCacheObjects: _maxCachedVideos,
      repo: JsonCacheInfoRepository(databaseName: 'video_cache'),
      fileService: HttpFileService(),
    ),
  );

  /// Get cache manager
  CacheManager get cacheManager => _cacheManager;

  /// Check if video is cached locally
  Future<File?> getCachedVideo(String url) async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(url);
      if (fileInfo != null && await fileInfo.file.exists()) {
        _log('✅ Video found in cache: $url');
        _updateAccessTime(url);
        return fileInfo.file;
      }
    } catch (e) {
      _log('⚠️ Error checking video cache: $e');
    }
    return null;
  }

  /// Download and cache video
  Future<File?> cacheVideo(String url) async {
    try {
      _log('⬇️ Downloading video to cache: $url');
      final file = await _cacheManager.getSingleFile(url);
      await _addToMetadata(url);
      _log('✅ Video cached successfully: $url');
      return file;
    } catch (e) {
      _log('❌ Error caching video: $e');
      return null;
    }
  }

  /// Get video file - first check cache, then download if needed
  Future<File?> getVideo(String url) async {
    // First try to get from cache
    final cachedFile = await getCachedVideo(url);
    if (cachedFile != null) {
      return cachedFile;
    }
    
    // Not in cache, download and cache
    return await cacheVideo(url);
  }

  /// Pre-cache multiple videos (call this when loading a video list)
  Future<void> preCacheVideos(List<String> urls) async {
    // Cache in background without blocking
    for (final url in urls.take(5)) { // Only pre-cache first 5
      getCachedVideo(url).then((cached) {
        if (cached == null) {
          cacheVideo(url); // Background download
        }
      });
    }
  }

  /// Clear old cache entries beyond limit
  Future<void> cleanupCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheMetadata = prefs.getStringList(_cacheKey) ?? [];
      
      if (cacheMetadata.length > _maxCachedVideos) {
        // Remove oldest entries
        final toRemove = cacheMetadata.take(cacheMetadata.length - _maxCachedVideos).toList();
        for (final url in toRemove) {
          await _cacheManager.removeFile(url);
          cacheMetadata.remove(url);
        }
        await prefs.setStringList(_cacheKey, cacheMetadata);
        _log('🗑️ Cleaned up ${toRemove.length} old cached videos');
      }
    } catch (e) {
      _log('⚠️ Error cleaning cache: $e');
    }
  }

  /// Clear entire video cache
  Future<void> clearCache() async {
    try {
      await _cacheManager.emptyCache();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      _log('🗑️ Video cache cleared');
    } catch (e) {
      _log('❌ Error clearing cache: $e');
    }
  }

  /// Get cache size info
  Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheMetadata = prefs.getStringList(_cacheKey) ?? [];
      
      // Get cache directory size
      final cacheDir = await getTemporaryDirectory();
      final videoCacheDir = Directory('${cacheDir.path}/libCachedImageData/video_cache');
      
      int totalSize = 0;
      if (await videoCacheDir.exists()) {
        await for (final file in videoCacheDir.list(recursive: true)) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }
      
      return {
        'cached_count': cacheMetadata.length,
        'size_bytes': totalSize,
        'size_mb': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      return {'cached_count': 0, 'size_bytes': 0, 'size_mb': '0'};
    }
  }

  /// Add URL to metadata for tracking
  Future<void> _addToMetadata(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheMetadata = prefs.getStringList(_cacheKey) ?? [];
    
    // Remove if exists (will add to end)
    cacheMetadata.remove(url);
    cacheMetadata.add(url);
    
    await prefs.setStringList(_cacheKey, cacheMetadata);
    
    // Cleanup if needed
    if (cacheMetadata.length > _maxCachedVideos) {
      await cleanupCache();
    }
  }

  /// Update access time by moving to end of list
  Future<void> _updateAccessTime(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheMetadata = prefs.getStringList(_cacheKey) ?? [];
    
    if (cacheMetadata.contains(url)) {
      cacheMetadata.remove(url);
      cacheMetadata.add(url);
      await prefs.setStringList(_cacheKey, cacheMetadata);
    }
  }
}
