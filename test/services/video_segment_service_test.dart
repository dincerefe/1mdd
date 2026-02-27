import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:digital_diary/services/video_segment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoSegmentService', () {
    late VideoSegmentService service;

    setUp(() {
      service = VideoSegmentService();
      SharedPreferences.setMockInitialValues({});
    });

    group('Session Management', () {
      test('hasExistingSession returns false when no session exists', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({});

        // Act
        final result = await service.hasExistingSession();

        // Assert
        expect(result, false);
      });

      test('hasExistingSession returns false when session is from different day', () async {
        // Arrange
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        SharedPreferences.setMockInitialValues({
          'video_session_date': yesterday.toIso8601String(),
          'video_segments': jsonEncode(['/path/to/segment.mp4']),
        });

        // Act
        final result = await service.hasExistingSession();

        // Assert
        expect(result, false);
      });

      test('cleanupOldSegments clears session from previous day', () async {
        // Arrange
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        SharedPreferences.setMockInitialValues({
          'video_session_date': yesterday.toIso8601String(),
          'video_segments': jsonEncode([]),
          'video_total_duration': 30,
        });

        // Act
        await service.cleanupOldSegments();

        // Assert
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('video_session_date'), isNull);
      });

      test('cleanupOldSegments does not clear today session', () async {
        // Arrange
        final today = DateTime.now();
        SharedPreferences.setMockInitialValues({
          'video_session_date': today.toIso8601String(),
          'video_segments': jsonEncode([]),
          'video_total_duration': 30,
        });

        // Act
        await service.cleanupOldSegments();

        // Assert
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('video_session_date'), isNotNull);
      });
    });

    group('Duration Management', () {
      test('getTotalDuration returns 0 when no duration saved', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({});

        // Act
        final duration = await service.getTotalDuration();

        // Assert
        expect(duration, 0);
      });

      test('getTotalDuration returns saved duration', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'video_total_duration': 45,
        });

        // Act
        final duration = await service.getTotalDuration();

        // Assert
        expect(duration, 45);
      });

      test('saveTotalDuration persists duration correctly', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({});

        // Act
        await service.saveTotalDuration(60);

        // Assert
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('video_total_duration'), 60);
      });
    });

    group('Segment Management', () {
      test('getSegments returns empty list when no segments exist', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({});

        // Act
        final segments = await service.getSegments();

        // Assert
        expect(segments, isEmpty);
      });

      test('addSegment adds segment to list and updates session date', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'video_segments': jsonEncode([]),
        });

        // Act
        await service.addSegment('/test/path/segment1.mp4');

        // Assert
        final prefs = await SharedPreferences.getInstance();
        final segmentsJson = prefs.getString('video_segments');
        final segments = jsonDecode(segmentsJson!) as List;
        expect(segments, contains('/test/path/segment1.mp4'));
        expect(prefs.getString('video_session_date'), isNotNull);
      });

      test('clearSession removes all segment data', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'video_segments': jsonEncode(['/path/to/segment.mp4']),
          'video_total_duration': 30,
          'video_session_date': DateTime.now().toIso8601String(),
        });

        // Act
        await service.clearSession();

        // Assert
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('video_segments'), isNull);
        expect(prefs.getInt('video_total_duration'), isNull);
        expect(prefs.getString('video_session_date'), isNull);
      });
    });

    group('Edge Cases', () {
      test('handles null session date gracefully', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({});

        // Act & Assert - should not throw
        await expectLater(
          service.cleanupOldSegments(),
          completes,
        );
      });

      test('handles malformed segments JSON gracefully', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'video_segments': 'invalid json',
        });

        // Act & Assert
        expect(
          () async => await service.getSegments(),
          throwsFormatException,
        );
      });

      test('getFirstSegment returns null when no segments exist', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({});

        // Act
        final firstSegment = await service.getFirstSegment();

        // Assert
        expect(firstSegment, isNull);
      });
    });
  });
}
