import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Requests all necessary permissions for the app to function correctly.
  /// This should be called on app startup.
  Future<void> requestInitialPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.notification,
    ].request();
    
    // Handle storage permissions based on platform
    if (Platform.isAndroid) {
      // For Android 13+ (SDK 33+), we need specific media permissions
      // For older versions, we need storage permission
      // Requesting all of them is safe; the OS/library will handle what's relevant
      await [
        Permission.photos,
        Permission.videos,
        Permission.storage,
        Permission.manageExternalStorage, // For Android 11+ full access if needed (usually not for just media)
      ].request();
    } else if (Platform.isIOS) {
      await [
        Permission.photos,
      ].request();
    }
  }

  /// Checks if camera permission is granted. If not, requests it.
  /// Returns true if granted, false otherwise.
  Future<bool> checkCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;
    
    status = await Permission.camera.request();
    return status.isGranted;
  }
  
  /// Checks if microphone permission is granted. If not, requests it.
  Future<bool> checkMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;
    
    status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Checks if notification permission is granted.
  Future<bool> checkNotificationPermission() async {
    var status = await Permission.notification.status;
    if (status.isGranted) return true;
    
    status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Opens the app settings page.
  Future<bool> openSettings() async {
    return openAppSettings();
  }
}
