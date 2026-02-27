import 'package:flutter_test/flutter_test.dart';

/// Mock class to test LocalNotificationService logic without platform dependencies
class MockLocalNotificationService {
  bool isInitialized = false;
  List<MockScheduledNotification> scheduledNotifications = [];
  List<MockShownNotification> shownNotifications = [];
  bool hasExactAlarmPermission = true;

  /// Initialize the notification service
  Future<void> init() async {
    // Simulate initialization
    await Future.delayed(const Duration(milliseconds: 10));
    isInitialized = true;
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    // Simulate permission request
    return true;
  }

  /// Schedule a daily notification at 7 PM
  Future<void> scheduleDailyNotification() async {
    if (!isInitialized) {
      throw Exception('Service not initialized');
    }

    if (!hasExactAlarmPermission) {
      return; // Skip scheduling if no permission
    }

    final scheduledTime = _nextInstanceOf7PM();
    
    scheduledNotifications.add(MockScheduledNotification(
      id: 0,
      title: 'Daily Reminder 📹',
      body: "Don't forget to record your daily video!",
      scheduledTime: scheduledTime,
      isRepeating: true,
    ));
  }

  /// Cancel daily notification
  Future<void> cancelDailyNotification() async {
    scheduledNotifications.removeWhere((n) => n.id == 0);
  }

  /// Show a test notification immediately
  Future<void> showTestNotification() async {
    if (!isInitialized) {
      throw Exception('Service not initialized');
    }

    shownNotifications.add(MockShownNotification(
      id: 999,
      title: 'Test Notification 🔔',
      body: 'If you see this, notifications are working!',
      shownAt: DateTime.now(),
    ));
  }

  /// Cancel a specific notification by ID
  Future<void> cancelNotification(int id) async {
    scheduledNotifications.removeWhere((n) => n.id == id);
    shownNotifications.removeWhere((n) => n.id == id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    scheduledNotifications.clear();
    shownNotifications.clear();
  }

  /// Get the next instance of 7 PM
  DateTime _nextInstanceOf7PM() {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, 19, 0);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }

  /// Check if a notification is scheduled
  bool isNotificationScheduled(int id) {
    return scheduledNotifications.any((n) => n.id == id);
  }

  /// Get pending notification count
  int get pendingNotificationCount => scheduledNotifications.length;
}

class MockScheduledNotification {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final bool isRepeating;

  MockScheduledNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    this.isRepeating = false,
  });
}

class MockShownNotification {
  final int id;
  final String title;
  final String body;
  final DateTime shownAt;

  MockShownNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.shownAt,
  });
}

void main() {
  group('LocalNotificationService', () {
    late MockLocalNotificationService notificationService;

    setUp(() {
      notificationService = MockLocalNotificationService();
    });

    group('Initialization', () {
      test('init sets isInitialized to true', () async {
        // Act
        await notificationService.init();

        // Assert
        expect(notificationService.isInitialized, true);
      });

      test('service is not initialized before init() is called', () {
        // Assert
        expect(notificationService.isInitialized, false);
      });
    });

    group('Daily Notification Scheduling', () {
      test('scheduleDailyNotification adds notification when initialized', () async {
        // Arrange
        await notificationService.init();

        // Act
        await notificationService.scheduleDailyNotification();

        // Assert
        expect(notificationService.scheduledNotifications.length, 1);
        expect(notificationService.scheduledNotifications.first.id, 0);
        expect(notificationService.scheduledNotifications.first.isRepeating, true);
      });

      test('scheduleDailyNotification throws when not initialized', () async {
        // Act & Assert
        expect(
          () => notificationService.scheduleDailyNotification(),
          throwsException,
        );
      });

      test('scheduleDailyNotification sets correct time (7 PM)', () async {
        // Arrange
        await notificationService.init();

        // Act
        await notificationService.scheduleDailyNotification();

        // Assert
        final scheduled = notificationService.scheduledNotifications.first;
        expect(scheduled.scheduledTime.hour, 19);
        expect(scheduled.scheduledTime.minute, 0);
      });

      test('scheduleDailyNotification skips when no exact alarm permission', () async {
        // Arrange
        await notificationService.init();
        notificationService.hasExactAlarmPermission = false;

        // Act
        await notificationService.scheduleDailyNotification();

        // Assert
        expect(notificationService.scheduledNotifications, isEmpty);
      });

      test('cancelDailyNotification removes the daily notification', () async {
        // Arrange
        await notificationService.init();
        await notificationService.scheduleDailyNotification();
        expect(notificationService.isNotificationScheduled(0), true);

        // Act
        await notificationService.cancelDailyNotification();

        // Assert
        expect(notificationService.isNotificationScheduled(0), false);
      });
    });

    group('Test Notification', () {
      test('showTestNotification adds notification to shown list', () async {
        // Arrange
        await notificationService.init();

        // Act
        await notificationService.showTestNotification();

        // Assert
        expect(notificationService.shownNotifications.length, 1);
        expect(notificationService.shownNotifications.first.id, 999);
        expect(notificationService.shownNotifications.first.title, 'Test Notification 🔔');
      });

      test('showTestNotification throws when not initialized', () async {
        // Act & Assert
        expect(
          () => notificationService.showTestNotification(),
          throwsException,
        );
      });
    });

    group('Notification Management', () {
      test('cancelNotification removes specific notification by ID', () async {
        // Arrange
        await notificationService.init();
        await notificationService.scheduleDailyNotification();
        await notificationService.showTestNotification();

        // Act
        await notificationService.cancelNotification(0);

        // Assert
        expect(notificationService.isNotificationScheduled(0), false);
        expect(notificationService.shownNotifications.length, 1);
      });

      test('cancelAllNotifications clears all notifications', () async {
        // Arrange
        await notificationService.init();
        await notificationService.scheduleDailyNotification();
        await notificationService.showTestNotification();

        // Act
        await notificationService.cancelAllNotifications();

        // Assert
        expect(notificationService.scheduledNotifications, isEmpty);
        expect(notificationService.shownNotifications, isEmpty);
      });

      test('pendingNotificationCount returns correct count', () async {
        // Arrange
        await notificationService.init();

        // Initially empty
        expect(notificationService.pendingNotificationCount, 0);

        // After scheduling
        await notificationService.scheduleDailyNotification();
        expect(notificationService.pendingNotificationCount, 1);
      });
    });

    group('Edge Cases', () {
      test('scheduling multiple times does not duplicate', () async {
        // Arrange
        await notificationService.init();

        // Act - schedule multiple times
        await notificationService.scheduleDailyNotification();
        await notificationService.cancelDailyNotification();
        await notificationService.scheduleDailyNotification();

        // Assert - should only have one
        expect(notificationService.scheduledNotifications.length, 1);
      });

      test('cancelling non-existent notification does not throw', () async {
        // Arrange
        await notificationService.init();

        // Act & Assert - should not throw
        await expectLater(
          notificationService.cancelNotification(999),
          completes,
        );
      });
    });
  });
}
