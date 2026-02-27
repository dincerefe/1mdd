import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final fln.FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      fln.FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    print('LocalNotificationService: Initializing...');
    try {
      tz.initializeTimeZones();

      const fln.AndroidInitializationSettings initializationSettingsAndroid =
          fln.AndroidInitializationSettings('@mipmap/launcher_icon');

      final fln.DarwinInitializationSettings initializationSettingsDarwin =
          fln.DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      final fln.InitializationSettings initializationSettings = fln.InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      final result = await flutterLocalNotificationsPlugin.initialize(initializationSettings);
      print('LocalNotificationService: Initialized with result: $result');
      
      // Request notification permission
      await _requestPermissions();
    } catch (e) {
      print('LocalNotificationService: Init error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    print('LocalNotificationService: Requesting permissions...');
    
    // Request Android notification permission (Android 13+)
    try {
      final notificationStatus = await Permission.notification.request();
      print('LocalNotificationService: Notification permission: $notificationStatus');

      // Request iOS notification permissions
      if (Platform.isIOS) {
        final iosPermission = await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                fln.IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        print('LocalNotificationService: iOS permission: $iosPermission');
      }
    } catch (e) {
      print('LocalNotificationService: Permission request error: $e');
    }
  }

  Future<void> scheduleDailyNotification() async {
    print('LocalNotificationService: Scheduling daily notification...');
    
    try {
      final scheduledTime = _nextInstanceOf7PM();
      print('LocalNotificationService: Scheduled for: $scheduledTime');
      
      await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'Daily Reminder 📹',
        'Don\'t forget to record your daily video!',
        scheduledTime,
        const fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            'daily_reminder_channel',
            'Daily Reminders',
            channelDescription: 'Reminds you to record your daily video',
            importance: fln.Importance.max,
            priority: fln.Priority.high,
            icon: '@mipmap/launcher_icon',
          ),
          iOS: fln.DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        // Use inexact scheduling to avoid requiring the "Exact alarm" permission.
        androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: fln.DateTimeComponents.time,
      );
      
      print('LocalNotificationService: Daily notification scheduled successfully');
    } catch (e) {
      print('LocalNotificationService: Failed to schedule notification: $e');
    }
  }

  Future<void> cancelDailyNotification() async {
    print('LocalNotificationService: Canceling daily notification...');
    try {
      await flutterLocalNotificationsPlugin.cancel(0);
    } catch (e) {
      print('LocalNotificationService: Error canceling notification: $e');
    }
  }

  // Test notification - shows immediately
  Future<void> showTestNotification() async {
    print('LocalNotificationService: Showing test notification...');
    try {
      await flutterLocalNotificationsPlugin.show(
        999,
        'Test Notification 🔔',
        'If you see this, notifications are working!',
        const fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            'test_channel',
            'Test Notifications',
            channelDescription: 'Test notifications',
            importance: fln.Importance.max,
            priority: fln.Priority.high,
            icon: '@mipmap/launcher_icon',
          ),
          iOS: fln.DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      print('LocalNotificationService: Test notification sent');
    } catch (e) {
      print('LocalNotificationService: Error showing test notification: $e');
    }
  }

  tz.TZDateTime _nextInstanceOf7PM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 19);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
