import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Debug print helper - only prints in debug mode
void _log(String message) {
  if (kDebugMode) {
    print(message);
  }
}

/// Service to manage video segments for persistent recording sessions
class VideoSegmentService {
  static const String _segmentsKey = 'video_segments';
  static const String _totalDurationKey = 'video_total_duration';
  static const String _sessionDateKey = 'video_session_date';
  static const String _segmentsDirName = 'video_segments';

  /// Get the directory for storing video segments
  Future<Directory> get _segmentsDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final segmentsDir = Directory('${appDir.path}/$_segmentsDirName');
    if (!await segmentsDir.exists()) {
      await segmentsDir.create(recursive: true);
    }
    return segmentsDir;
  }

  /// Check if there's an existing session from today
  Future<bool> hasExistingSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionDateStr = prefs.getString(_sessionDateKey);
    if (sessionDateStr == null) return false;

    final sessionDate = DateTime.parse(sessionDateStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);

    // Session is valid only if it's from today
    if (sessionDay.isAtSameMomentAs(today)) {
      final segments = await getSegments();
      return segments.isNotEmpty;
    } else {
      // Clear old session
      await clearSession();
      return false;
    }
  }

  /// Clean up segments from previous days
  Future<void> cleanupOldSegments() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionDateStr = prefs.getString(_sessionDateKey);
    if (sessionDateStr == null) return;

    final sessionDate = DateTime.parse(sessionDateStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);

    // If session is from a previous day, clear it
    if (!sessionDay.isAtSameMomentAs(today)) {
      _log('🗑️ Cleaning up old segments from ${sessionDay.toString()}');
      await clearSession();
    }
  }

  /// Get the total recorded duration from saved segments
  Future<int> getTotalDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalDurationKey) ?? 0;
  }

  /// Save total duration
  Future<void> saveTotalDuration(int duration) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_totalDurationKey, duration);
  }

  /// Get list of saved segment paths
  Future<List<String>> getSegments() async {
    final prefs = await SharedPreferences.getInstance();
    final segmentsJson = prefs.getString(_segmentsKey);
    if (segmentsJson == null) return [];
    
    final List<dynamic> segments = jsonDecode(segmentsJson);
    // Filter out segments that no longer exist
    final validSegments = <String>[];
    for (final segment in segments) {
      final path = segment is String ? segment : (segment['path'] as String?);
      if (path != null && await File(path).exists()) {
        validSegments.add(path);
      }
    }
    return validSegments;
  }

  /// Add a new segment
  Future<void> addSegment(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final segments = await getSegments();
    segments.add(path);
    await prefs.setString(_segmentsKey, jsonEncode(segments));
    
    // Update session date
    await prefs.setString(_sessionDateKey, DateTime.now().toIso8601String());
  }

  /// Save a video file as a segment
  Future<String> saveSegment(File videoFile) async {
    final segmentsDir = await _segmentsDirectory;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final segmentPath = '${segmentsDir.path}/segment_$timestamp.mp4';
    
    // Copy the video file to segments directory
    await videoFile.copy(segmentPath);
    await addSegment(segmentPath);
    
    return segmentPath;
  }

  /// Combine all segments into a single video file
  /// Returns the path to the combined video, or null if no segments
  Future<File?> combineSegments() async {
    final segments = await getSegments();
    if (segments.isEmpty) return null;
    
    // If only one segment, just return it
    if (segments.length == 1) {
      return File(segments.first);
    }

    // For multiple segments, we need to concatenate them
    // Using a simple approach: create a combined file
    final segmentsDir = await _segmentsDirectory;
    final outputPath = '${segmentsDir.path}/combined_${DateTime.now().millisecondsSinceEpoch}.mp4';
    
    // Simple concatenation by reading and writing bytes
    // Note: This works for same-codec MP4 files
    final outputFile = File(outputPath);
    final sink = outputFile.openWrite();
    
    for (int i = 0; i < segments.length; i++) {
      final segmentFile = File(segments[i]);
      if (await segmentFile.exists()) {
        final bytes = await segmentFile.readAsBytes();
        sink.add(bytes);
      }
    }
    
    await sink.close();
    
    return outputFile;
  }

  /// Get segments as File objects for proper video merging
  Future<List<File>> getSegmentFiles() async {
    final segments = await getSegments();
    return segments.map((path) => File(path)).toList();
  }

  /// Clear all segments and session data
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Delete segment files
    final segments = await getSegments();
    for (final segmentPath in segments) {
      final file = File(segmentPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    // Clear preferences
    await prefs.remove(_segmentsKey);
    await prefs.remove(_totalDurationKey);
    await prefs.remove(_sessionDateKey);
    
    // Clean up segments directory
    try {
      final segmentsDir = await _segmentsDirectory;
      if (await segmentsDir.exists()) {
        await segmentsDir.delete(recursive: true);
      }
    } catch (e) {
      _log('Error cleaning segments directory: $e');
    }
  }

  /// Get the first segment as the main video (for single segment case)
  Future<File?> getFirstSegment() async {
    final segments = await getSegments();
    if (segments.isEmpty) return null;
    return File(segments.first);
  }
}
