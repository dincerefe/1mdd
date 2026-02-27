import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_diary/main.dart';
import 'package:digital_diary/screens/save_video_screen.dart';
import 'package:digital_diary/services/local_notification_service.dart';
import 'package:digital_diary/services/permission_service.dart';
import 'package:digital_diary/services/video_segment_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> 
    with WidgetsBindingObserver {
  
  bool _isLoading = true;
  bool _hasRecordedToday = false;
  bool _isActive = true;
  bool _isVisible = true; // Track if screen is visible in PageView
  bool _permissionDenied = false; // Track if permission was denied to prevent flickering
  CameraController? _controller;
  bool _isInitializingCamera = false;
  int _cameraIndex = 0;
  bool _isRecording = false;
  bool _isPaused = false;

  // Keep camera loading UIs visible long enough to avoid flicker.
  static const Duration _minCameraLoadingDuration = Duration(milliseconds: 700);
  static const Duration _minCameraSwitchLoadingDuration = Duration(milliseconds: 450);
  DateTime? _cameraLoadingStartedAt;
  DateTime? _cameraSwitchStartedAt;
  
  // Timer logic
  bool _isPremium = false;
  Timer? _timer;
  int _recordDuration = 0;
  int get _maxDuration => _isPremium ? 300 : 60;

  // State variables for zoom functionality
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;
  double _baseZoomLevel = 1.0;

  // Segment management
  final VideoSegmentService _segmentService = VideoSegmentService();
  List<String> _segments = [];
  bool _hasExistingSession = false;
  bool _isSwitchingCamera = false;

  // Merging progress
  bool _isMerging = false;
  String _mergeStatus = '';
  double _mergeProgress = 0.0;
  int _currentMergeStep = 0;
  int _totalMergeSteps = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndInitialize();
  }

  void _beginCameraLoading() {
    _cameraLoadingStartedAt = DateTime.now();
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    } else {
      _isLoading = true;
    }
  }

  Future<void> _endCameraLoading({bool honorMinDuration = true}) async {
    if (honorMinDuration) {
      final startedAt = _cameraLoadingStartedAt;
      if (startedAt != null) {
        final elapsed = DateTime.now().difference(startedAt);
        final remaining = _minCameraLoadingDuration - elapsed;
        if (remaining > Duration.zero) {
          await Future<void>.delayed(remaining);
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    } else {
      _isLoading = false;
    }
  }

  @override
  void activate() {
    super.activate();
    _isActive = true;

    // When coming back from another route, Flutter calls deactivate()/activate()
    // without changing app lifecycle state. Ensure camera is re-initialized.
    Future.microtask(() async {
      if (!mounted) return;
      if (_permissionDenied || _hasRecordedToday || _isMerging) return;

      final controllerReady =
          _controller != null && _controller!.value.isInitialized;
      if (!controllerReady && !_isLoading) {
        await _checkAndInitialize();
      }
    });
  }

  Future<void> _disposeControllerSafely() async {
    final controller = _controller;
    if (controller == null) return;

    // IMPORTANT: remove CameraPreview from the widget tree BEFORE disposing,
    // otherwise the framework can call buildPreview() on a disposed controller.
    if (mounted) {
      setState(() {
        _controller = null;
      });
      await Future<void>.delayed(Duration.zero);
    } else {
      _controller = null;
    }

    try {
      if (controller.value.isInitialized) {
        await controller.pausePreview();
      }
    } catch (_) {
      // ignore
    }
    try {
      await controller.dispose();
    } catch (_) {
      // ignore
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null && !_hasRecordedToday && !_isLoading) {
      _checkAndInitialize();
    }
  }

  Future<void> _checkAndInitialize() async {
    if(!mounted || !_isActive) return;

    _beginCameraLoading();

    // Only check permission status, don't request yet
    // This prevents the loop where requesting triggers rebuild
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;
    
    final hasCamera = cameraStatus.isGranted;
    final hasMic = micStatus.isGranted;

    if (!hasCamera || !hasMic) {
      if (mounted) {
        setState(() { 
          _permissionDenied = true;
        });
      }
      await _endCameraLoading(honorMinDuration: false);
      return;
    }

    // Permission granted
    if (mounted) {
      setState(() { 
        _permissionDenied = false;
      });
    }

    // Fetch user premium status
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted) {
          setState(() {
            _isPremium = userDoc.data()?['isPremium'] ?? false;
          });
        }
      } catch (e) {
        print("Error fetching user premium status: $e");
      }
    }

    // Check for existing session and clean up old segments if day changed
    await _segmentService.cleanupOldSegments();
    _hasExistingSession = await _segmentService.hasExistingSession();
    if (_hasExistingSession) {
      _segments = await _segmentService.getSegments();
      _recordDuration = await _segmentService.getTotalDuration();
    }

    final hasRecorded = await _checkIfRecordedToday();
    if (mounted && _isActive) {
      setState(() {
        _hasRecordedToday = hasRecorded;
      });
      if (!hasRecorded) {
        if(_controller == null) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted && _isActive) {
            await _initializeCamera();
          }
        }
      } else {
        await _disposeControllerSafely();
      }
      await _endCameraLoading();
    }
  }

  /// Actually request permission - called from permission screen button
  Future<void> _requestPermissions() async {
    // Request permissions without blocking UI
    final results = await Future.wait([
      Permission.camera.request(),
      Permission.microphone.request(),
    ]);
    
    final cameraResult = results[0];
    final micResult = results[1];
    
    if (cameraResult.isGranted && micResult.isGranted) {
      // Permission granted, re-initialize
      if (mounted) {
        setState(() { 
          _permissionDenied = false;
          _isLoading = true;
        });
      }
      await _checkAndInitialize();
    } else {
      // Still denied - stay on permission screen
      if (mounted) {
        setState(() { 
          _permissionDenied = true;
        });
      }
    }
  }

  /// Build beautiful permission request screen
  Widget _buildPermissionScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.grey[100];
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardColor = isDark ? Colors.grey[900] : Colors.white;

    return Container(
      color: bgColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with gradient background
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepOrange.withOpacity(0.2),
                      Colors.orange.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.videocam_off_rounded,
                    size: 60,
                    color: Colors.deepOrange,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                'Camera Access Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Description
              Text(
                'To record your daily moments, we need access to your camera and microphone.',
                style: TextStyle(
                  fontSize: 16,
                  color: subtextColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Permission items
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark ? null : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildPermissionItem(
                      Icons.camera_alt_rounded,
                      'Camera',
                      'Record video memories',
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildPermissionItem(
                      Icons.mic_rounded,
                      'Microphone',
                      'Capture audio with your videos',
                      isDark,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Only Open Settings button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await openAppSettings();
                  },
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Open Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem(IconData icon, String title, String subtitle, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.deepOrange, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool> _checkIfRecordedToday() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return true;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final query = await FirebaseFirestore.instance
          .collection('videos')
          .where('uid', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
          .where('createdAt', isLessThan: endOfDay)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      print("Error checking for today's video: $e");
      return true;
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted || !_isActive) return;
    if (_isInitializingCamera) return;
    _isInitializingCamera = true;

    if (cameras.isEmpty) {
      try {
        cameras = await availableCameras();
      } catch (e) {
        print("Error fetching cameras: $e");
      }
    }
    
    if (cameras.isEmpty) {
      _isInitializingCamera = false;
      return;
    }

    await _disposeControllerSafely();

    // Give Android a moment to release the previous camera session.
    await Future.delayed(const Duration(milliseconds: 120));

    final camera = cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
      fps: 30,
    );
    try {
      await _controller!.initialize();
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposureMode(ExposureMode.auto);
      
      _minZoomLevel = await _controller!.getMinZoomLevel();
      _maxZoomLevel = await _controller!.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing camera: $e');
      await _disposeControllerSafely();
    } finally {
      _isInitializingCamera = false;
    }
  }

  /// Switch camera while recording - saves current segment and continues with new camera
  Future<void> _switchCamera() async {
    if (cameras.length <= 1) return;
    
    if (_isRecording && !_isSwitchingCamera) {
      _cameraSwitchStartedAt = DateTime.now();
      setState(() { _isSwitchingCamera = true; });
      
      try {
        // Stop current recording and save segment
        if (_controller != null && _controller!.value.isRecordingVideo) {
          final file = await _controller!.stopVideoRecording();
          final segmentPath = await _segmentService.saveSegment(File(file.path));
          _segments.add(segmentPath);
          await _segmentService.saveTotalDuration(_recordDuration);
        }
        
        // Switch camera
        _cameraIndex = (_cameraIndex + 1) % cameras.length;
        await _initializeCamera();
        
        // Resume recording with new camera
        if (_controller != null && _controller!.value.isInitialized) {
          await _controller!.startVideoRecording();
        }
        
        final startedAt = _cameraSwitchStartedAt;
        if (startedAt != null) {
          final elapsed = DateTime.now().difference(startedAt);
          final remaining = _minCameraSwitchLoadingDuration - elapsed;
          if (remaining > Duration.zero) {
            await Future<void>.delayed(remaining);
          }
        }
        setState(() { _isSwitchingCamera = false; });
      } catch (e) {
        print('Error switching camera during recording: $e');
        setState(() { _isSwitchingCamera = false; });
      }
    } else if (!_isRecording) {
      // Normal camera switch when not recording
      if (_isSwitchingCamera) return;
      _cameraSwitchStartedAt = DateTime.now();
      setState(() { _isSwitchingCamera = true; });
      try {
        _cameraIndex = (_cameraIndex + 1) % cameras.length;
        await _initializeCamera();
      } catch (e) {
        print('Error switching camera: $e');
      } finally {
        if (mounted) {
          final startedAt = _cameraSwitchStartedAt;
          if (startedAt != null) {
            final elapsed = DateTime.now().difference(startedAt);
            final remaining = _minCameraSwitchLoadingDuration - elapsed;
            if (remaining > Duration.zero) {
              await Future<void>.delayed(remaining);
            }
          }
          setState(() { _isSwitchingCamera = false; });
        }
      }
    }
  }

  Future<void> _togglePause() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) {
      return;
    }

    try {
      if (_isPaused) {
        await _controller!.resumeVideoRecording();
        setState(() { _isPaused = false; });
      } else {
        await _controller!.pauseVideoRecording();
        setState(() { _isPaused = true; });
      }
    } catch (e) {
      print('Error toggling pause: $e');
    }
  }

  Future<void> _toggleRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      print("Controller not ready");
      return;
    }

    try {
      if (_controller!.value.isRecordingVideo && !_isPaused) {
        await _stopRecording();
      } else if (_isPaused) {
        await _stopRecording();
      } else {
        // Start recording
        await _controller!.startVideoRecording();
        _startTimer();
        setState(() { 
          _isRecording = true;
          _isPaused = false;
        });
      }
    } catch (e) {
      print('Error during video recording toggle: $e');
      if (mounted) {
        setState(() { 
          _isRecording = false;
          _isPaused = false;
        });
        _timer?.cancel();
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null) return;
    
    try {
      final file = await _controller!.stopVideoRecording();
      _timer?.cancel();
      
      // Save current segment
      final segmentPath = await _segmentService.saveSegment(File(file.path));
      _segments.add(segmentPath);
      await _segmentService.saveTotalDuration(_recordDuration);
      
      setState(() { 
        _isRecording = false;
        _isPaused = false;
      });

      // Show dialog to continue or finish
      if (mounted) {
        _showRecordingOptionsDialog();
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  void _showRecordingOptionsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _SegmentManagerSheet(
        segments: _segments,
        totalDuration: _recordDuration,
        onContinue: () {
          Navigator.of(context).pop();
        },
        onDiscard: () async {
          Navigator.of(context).pop();
          await _discardRecording();
        },
        onFinish: (selectedSegments) async {
          Navigator.of(context).pop();
          if (selectedSegments.isNotEmpty) {
            _segments = selectedSegments;
          }
          await _finishRecording();
        },
        onDeleteSegment: (index) async {
          final segmentPath = _segments[index];
          _segments.removeAt(index);
          
          // Delete the file
          try {
            final file = File(segmentPath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            print('Error deleting segment: $e');
          }
          
          // Recalculate duration (approximate)
          if (_segments.isEmpty) {
            _recordDuration = 0;
          }
          
          await _segmentService.saveTotalDuration(_recordDuration);
        },
      ),
    );
  }

  Future<void> _discardRecording() async {
    await _segmentService.clearSession();
    _segments.clear();
    _recordDuration = 0;
    _hasExistingSession = false;
    setState(() {});
  }

  Future<void> _finishRecording() async {
    if (_segments.isEmpty) return;
    
    setState(() { 
      _isLoading = true;
      _isMerging = _segments.length > 1;
      _mergeStatus = 'Preparing...';
      _mergeProgress = 0.0;
      _currentMergeStep = 0;
      _totalMergeSteps = _segments.length > 1 ? _segments.length + 1 : 0; // +1 for final merge
    });
    
    try {
      File? finalVideo;
      
      if (_segments.length == 1) {
        // Single segment - copy to a safe location
        final segmentFile = File(_segments.first);
        if (await segmentFile.exists()) {
          final appDir = await getApplicationDocumentsDirectory();
          final safePath = '${appDir.path}/final_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
          finalVideo = await segmentFile.copy(safePath);
          print('Single segment copied to: $safePath');
        } else {
          print('Segment file does not exist: ${_segments.first}');
        }
      } else {
        // Multiple segments - merge them using FFmpeg
        finalVideo = await _mergeSegments();
      }
      
      if (finalVideo != null && await finalVideo.exists()) {
        final fileSize = await finalVideo.length();
        print('Final video ready: ${finalVideo.path}, size: $fileSize bytes');
        
        // Cancel the daily notification
        await LocalNotificationService().cancelDailyNotification();
        
        setState(() { 
          _isLoading = false;
          _isMerging = false;
        });
        
        if (mounted) {
          // Navigate to SaveVideoScreen and wait for result
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => SaveVideoScreen(videoFile: finalVideo!),
            ),
          );
          
          // Only clear session if upload was successful (result == true)
          if (result == true) {
            await _segmentService.clearSession();
            _segments.clear();
            _recordDuration = 0;
            _hasExistingSession = false;
          }
          // If user went back (result == false or null), session remains intact
          
          _checkAndInitialize();
        }
      } else {
        setState(() { 
          _isLoading = false;
          _isMerging = false;
        });
        _showErrorDialog('Failed to process video. File not found.');
      }
    } catch (e) {
      print('Error finishing recording: $e');
      setState(() { 
        _isLoading = false;
        _isMerging = false;
      });
      _showErrorDialog('Error processing video: $e');
    }
  }

  /// Merge multiple video segments using FFmpeg
  /// All segments are converted to portrait orientation (720x1280)
  Future<File?> _mergeSegments() async {
    if (_segments.isEmpty) return null;
    if (_segments.length == 1) return File(_segments.first);
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = '${appDir.path}/temp_normalized';
      await Directory(tempDir).create(recursive: true);
      
      final normalizedSegments = <String>[];
      
      for (int i = 0; i < _segments.length; i++) {
        // Update progress UI
        setState(() {
          _currentMergeStep = i + 1;
          _mergeProgress = (_currentMergeStep / _totalMergeSteps);
          _mergeStatus = 'Processing segment (${i + 1}/${_segments.length})';
        });
        
        final segmentPath = _segments[i];
        final file = File(segmentPath);
        if (!await file.exists()) continue;
        
        final normalizedPath = '$tempDir/normalized_$i.mp4';
        
        // Force all videos to portrait 720x1280, apply auto-rotation and reset metadata
        // scale=720:1280:force_original_aspect_ratio=decrease - scales to fit within 720x1280
        // pad=720:1280:(ow-iw)/2:(oh-ih)/2 - pads with black bars if needed to get exact 720x1280
        final normalizeCommand = '-i "$segmentPath" -vf "scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,setsar=1" -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k -r 30 "$normalizedPath"';
        
        print('Normalizing segment $i to portrait');
        final session = await FFmpegKit.execute(normalizeCommand);
        final returnCode = await session.getReturnCode();
        
        if (ReturnCode.isSuccess(returnCode) && await File(normalizedPath).exists()) {
          normalizedSegments.add(normalizedPath);
          print('Segment $i normalized successfully');
        } else {
          final logs = await session.getAllLogsAsString();
          print('Normalization failed for segment $i: $logs');
          normalizedSegments.add(segmentPath);
        }
      }
      
      if (normalizedSegments.isEmpty) {
        await _cleanupTempDir(tempDir);
        return File(_segments.first);
      }
      
      if (normalizedSegments.length == 1) {
        return File(normalizedSegments.first);
      }
      
      // Update progress for final merge step
      setState(() {
        _currentMergeStep = _totalMergeSteps;
        _mergeProgress = 0.95;
        _mergeStatus = 'Merging video...';
      });
      
      final outputPath = '${appDir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final listFilePath = '${appDir.path}/segments_list.txt';
      final listFile = File(listFilePath);
      
      final buffer = StringBuffer();
      for (final segmentPath in normalizedSegments) {
        buffer.writeln("file '$segmentPath'");
      }
      await listFile.writeAsString(buffer.toString());
      
      // Concat - since all are now same format, copy should work
      String command = '-f concat -safe 0 -i "$listFilePath" -c copy "$outputPath"';
      print('FFmpeg concat command: $command');
      
      var session = await FFmpegKit.execute(command);
      var returnCode = await session.getReturnCode();
      
      if (await listFile.exists()) {
        await listFile.delete();
      }
      
      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          print('Video merge successful');
          setState(() {
            _mergeProgress = 1.0;
            _mergeStatus = 'Done!';
          });
          await _cleanupTempDir(tempDir);
          return outputFile;
        }
      }
      
      // Fallback: re-encode concat
      print('Concat copy failed, re-encoding...');
      setState(() {
        _mergeStatus = 'Optimizing video...';
      });
      
      final logs = await session.getAllLogsAsString();
      print('FFmpeg logs: $logs');
      
      await listFile.writeAsString(buffer.toString());
      command = '-f concat -safe 0 -i "$listFilePath" -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k "$outputPath"';
      session = await FFmpegKit.execute(command);
      returnCode = await session.getReturnCode();
      
      if (await listFile.exists()) {
        await listFile.delete();
      }
      await _cleanupTempDir(tempDir);
      
      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          setState(() {
            _mergeProgress = 1.0;
            _mergeStatus = 'Done!';
          });
          return outputFile;
        }
      }
      
      return File(_segments.first);
    } catch (e) {
      print('Error merging segments: $e');
      return _segments.isNotEmpty ? File(_segments.first) : null;
    }
  }

  /// Clean up temporary directory
  Future<void> _cleanupTempDir(String tempDir) async {
    try {
      final dir = Directory(tempDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      print('Error cleaning temp dir: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    // Don't reset duration if resuming from existing session
    if (!_hasExistingSession || _segments.isEmpty) {
      // Keep existing duration from saved session
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused || _isSwitchingCamera) return;
      
      setState(() {
        _recordDuration++;
      });

      if (_recordDuration >= _maxDuration) {
        _stopRecording();
      }
    });
  }

  /// Save current state when app goes to background during recording
  Future<void> _saveCurrentState() async {
    if (_isRecording && _controller != null && _controller!.value.isRecordingVideo) {
      try {
        final file = await _controller!.stopVideoRecording();
        await _segmentService.saveSegment(File(file.path));
        await _segmentService.saveTotalDuration(_recordDuration);
        _segments = await _segmentService.getSegments();
      } catch (e) {
        print('Error saving state: $e');
      }
    }
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });
  }

  /// Called when user navigates away from camera tab in HomeScreen
  Future<void> onPageLeft() async {
    _isVisible = false;
    await _saveCurrentState();
    // Release the camera when user leaves the camera tab to avoid
    // stale controller states when returning from other tabs.
    await _disposeControllerSafely();
  }

  /// Called when user navigates back to camera tab in HomeScreen
  Future<void> onPageReturned() async {
    _isVisible = true;
    _isActive = true;
    
    // If permission was denied, recheck
    if (_permissionDenied) {
      await _recheckPermissionAfterSettings();
      return;
    }
    
    // If controller exists and is initialized, just resume preview
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        await _controller!.resumePreview();
      } catch (e) {
        print('Error resuming preview: $e');
        // If resume fails, reinitialize
        await _checkAndInitialize();
      }
    } else {
      // Controller is null or not initialized - reinitialize
      await _checkAndInitialize();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    // Best-effort cleanup; can't await in dispose.
    final controller = _controller;
    _controller = null;
    try {
      controller?.pausePreview();
    } catch (_) {
      // ignore
    }
    try {
      controller?.dispose();
    } catch (_) {
      // ignore
    }
    super.dispose();
  }

  @override
  void deactivate() {
    _isActive = false;
    _timer?.cancel();
    // Release camera when this route is covered by another route.
    // If/when we become active again, activate() will re-initialize.
    _disposeControllerSafely();
    super.deactivate();
  }

  @override
  void didUpdateWidget(CameraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _isActive = true;
    if (_controller == null && !_hasRecordedToday && !_isLoading) {
      _initializeCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      // App is about to go to background - save immediately
      _saveStateImmediately();
    } else if (state == AppLifecycleState.paused) {
      // Already in background, cleanup
      _isActive = false;
      _timer?.cancel();
      _disposeControllerSafely();
    } else if (state == AppLifecycleState.resumed) {
      // App resumed - check if permission was granted while in settings
      _isActive = true;
      if (_isVisible) {
        // If permission was denied before, re-check now
        if (_permissionDenied) {
          _recheckPermissionAfterSettings();
        } else if (_controller == null && !_hasRecordedToday) {
          _checkAndInitialize();
        } else if (_controller != null && !_controller!.value.isInitialized) {
          _checkAndInitialize();
        }
      }
    }
  }

  /// Re-check permissions after user returns from settings
  Future<void> _recheckPermissionAfterSettings() async {
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;
    
    if (cameraStatus.isGranted && micStatus.isGranted) {
      // Permission was granted! Re-initialize
      if (mounted) {
        setState(() {
          _permissionDenied = false;
          _isLoading = true;
        });
      }
      await _checkAndInitialize();
    }
    // If still denied, stay on permission screen (no change needed)
  }

  /// Synchronously stop recording and save - called when app goes to background
  void _saveStateImmediately() {
    if (_isRecording && _controller != null && _controller!.value.isRecordingVideo) {
      _timer?.cancel();
      _controller!.stopVideoRecording().then((file) async {
        try {
          await _segmentService.saveSegment(File(file.path));
          await _segmentService.saveTotalDuration(_recordDuration);
          _segments = await _segmentService.getSegments();
          print('Segment saved on background: ${file.path}');
        } catch (e) {
          print('Error saving segment on background: $e');
        }
      }).catchError((e) {
        print('Error stopping recording on background: $e');
      });
      
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isPaused = false;
        });
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Widget _buildThemedLoadingIndicator(bool isDark, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepOrange),
              backgroundColor: isDark 
                  ? Colors.deepOrange.withOpacity(0.2) 
                  : Colors.deepOrange.withOpacity(0.1),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMergingScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.grey.shade100;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white.withOpacity(0.6) : Colors.black54;
    final cardColor = isDark ? Colors.white.withOpacity(0.1) : Colors.white;
    final progressBgColor = isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300;
    
    return Container(
      color: bgColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated video icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 2),
                builder: (context, value, child) {
                  return Transform.rotate(
                    angle: value * 0.1,
                    child: Icon(
                      Icons.video_library_rounded,
                      size: 80,
                      color: Colors.deepOrange.withOpacity(0.8 + (value * 0.2)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              
              // Title
              Text(
                'Preparing Your Video',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              
              // Status text
              Text(
                _mergeStatus,
                style: TextStyle(
                  fontSize: 16,
                  color: subtextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Progress bar
              Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  color: progressBgColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: constraints.maxWidth * _mergeProgress,
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.deepOrange, Colors.orange],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepOrange.withOpacity(0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // Percentage text
              Text(
                '${(_mergeProgress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
              const SizedBox(height: 8),
              
              // Step indicator
              if (_totalMergeSteps > 0)
                Text(
                  'Step $_currentMergeStep of $_totalMergeSteps',
                  style: TextStyle(
                    fontSize: 14,
                    color: subtextColor,
                  ),
                ),
              
              const SizedBox(height: 32),
              
              // Info text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isDark ? null : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: subtextColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Merging video segments. Please wait...',
                        style: TextStyle(
                          fontSize: 13,
                          color: subtextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Show permission screen when permission is denied
    if (_permissionDenied) {
      return SafeArea(child: _buildPermissionScreen());
    }
    
    // Show merging screen when processing video
    if (_isMerging) {
      return SafeArea(child: _buildMergingScreen());
    }

    if (_isSwitchingCamera) {
      return SafeArea(child: _buildThemedLoadingIndicator(isDark, 'Switching camera...'));
    }
    
    if (_isLoading) {
      return SafeArea(child: _buildThemedLoadingIndicator(isDark, 'Preparing camera...'));
    }

    if (_hasRecordedToday) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Colors.deepOrange,
                ),
                const SizedBox(height: 16),
                Text(
                  "Today's Memory Saved!",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Come back tomorrow for your next entry',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_off_outlined,
                size: 60,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Camera is not available',
                style: TextStyle(
                  fontSize: 18,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isActive = true;
                    _isLoading = true;
                  });
                  _checkAndInitialize();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    var scale = 1.0;
    if (_controller != null && _controller!.value.isInitialized) {
      final size = MediaQuery.of(context).size;
      final deviceRatio = size.aspectRatio;
      final cameraRatio = _controller!.value.aspectRatio;
      scale = 1 / (cameraRatio * deviceRatio);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (details) {
        _baseZoomLevel = _currentZoomLevel;
      },
      onScaleUpdate: (details) async {
        final newZoomLevel = (_baseZoomLevel * details.scale)
            .clamp(_minZoomLevel, _maxZoomLevel);

        if (newZoomLevel != _currentZoomLevel) {
          final controller = _controller;
          if (controller == null || !controller.value.isInitialized) return;
          try {
            await controller.setZoomLevel(newZoomLevel);
          } catch (_) {
            return;
          }
          if (!mounted) return;
          setState(() {
            _currentZoomLevel = newZoomLevel;
          });
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: scale,
            child: Center(child: CameraPreview(_controller!)),
          ),
          // Session info banner (shows when there's an existing session)
          if (_hasExistingSession && _segments.isNotEmpty && !_isRecording)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Continue recording (${_formatDuration(_recordDuration)} saved)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          // Timer Display
          if (_isRecording)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSwitchingCamera)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(_recordDuration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_segments.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${_segments.length} clips)',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Positioned.fill(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Pause Button (only visible when recording)
                if (_isRecording)
                  IconButton(
                    icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white),
                    onPressed: _isSwitchingCamera ? null : _togglePause,
                    iconSize: 32,
                  )
                else
                  const SizedBox(width: 48),

                GestureDetector(
                  onTap: _isSwitchingCamera ? null : _toggleRecording,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isRecording)
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            value: _recordDuration / _maxDuration,
                            strokeWidth: 5,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                            backgroundColor: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isRecording
                              ? Icons.stop_rounded
                              : Icons.fiber_manual_record,
                          color: Colors.red,
                          size: _isRecording ? 32 : 72,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Camera flip button - now works during recording too
                IconButton(
                  icon: Icon(
                    Icons.flip_camera_ios, 
                    color: _isSwitchingCamera ? Colors.grey : Colors.white,
                  ),
                  onPressed: _isSwitchingCamera ? null : _switchCamera,
                  iconSize: 32,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Beautiful Segment Manager Bottom Sheet
class _SegmentManagerSheet extends StatefulWidget {
  final List<String> segments;
  final int totalDuration;
  final VoidCallback onContinue;
  final VoidCallback onDiscard;
  final Function(List<String>) onFinish;
  final Function(int) onDeleteSegment;

  const _SegmentManagerSheet({
    required this.segments,
    required this.totalDuration,
    required this.onContinue,
    required this.onDiscard,
    required this.onFinish,
    required this.onDeleteSegment,
  });

  @override
  State<_SegmentManagerSheet> createState() => _SegmentManagerSheetState();
}

class _SegmentManagerSheetState extends State<_SegmentManagerSheet> {
  late List<String> _segments;
  late Set<int> _selectedIndices;
  final Map<String, Uint8List?> _thumbnails = {};
  bool _isLoadingThumbnails = true;

  @override
  void initState() {
    super.initState();
    _segments = List.from(widget.segments);
    _selectedIndices = Set.from(List.generate(_segments.length, (i) => i));
    _loadThumbnails();
  }

  Future<void> _loadThumbnails() async {
    for (int i = 0; i < _segments.length; i++) {
      final segmentPath = _segments[i];
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final thumbnailPath = '${appDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        
        // Use FFmpeg to extract a frame from the video
        final command = '-i "$segmentPath" -ss 00:00:00.500 -vframes 1 -q:v 2 "$thumbnailPath"';
        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();
        
        if (ReturnCode.isSuccess(returnCode)) {
          final thumbFile = File(thumbnailPath);
          if (await thumbFile.exists()) {
            final bytes = await thumbFile.readAsBytes();
            if (mounted) {
              setState(() {
                _thumbnails[segmentPath] = bytes;
              });
            }
            // Clean up thumbnail file
            await thumbFile.delete();
          }
        }
      } catch (e) {
        print('Error loading thumbnail for segment $i: $e');
      }
    }
    
    if (mounted) {
      setState(() {
        _isLoadingThumbnails = false;
      });
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        if (_selectedIndices.length > 1) {
          _selectedIndices.remove(index);
        }
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _deleteSegment(int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Delete Segment?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                'This segment will be permanently deleted and cannot be recovered.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? Colors.white60 : Colors.black54,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                          ),
                        ),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        widget.onDeleteSegment(index);
                        setState(() {
                          _segments.removeAt(index);
                          _selectedIndices.remove(index);
                          // Reindex selected indices
                          _selectedIndices = _selectedIndices
                              .map((i) => i > index ? i - 1 : i)
                              .where((i) => i >= 0 && i < _segments.length)
                              .toSet();
                          if (_selectedIndices.isEmpty && _segments.isNotEmpty) {
                            _selectedIndices.add(0);
                          }
                        });
                        
                        if (_segments.isEmpty) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final cardColor = isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade100;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.video_library_rounded,
                        color: Colors.deepOrange,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Recording',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_segments.length} segment${_segments.length > 1 ? 's' : ''} • ${_formatDuration(widget.totalDuration)} total',
                            style: TextStyle(
                              fontSize: 14,
                              color: subtextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Selection info
                if (_segments.length > 1) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.deepOrange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.deepOrange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tap to select/deselect segments. Long press to delete.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.deepOrange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Segments list
          Expanded(
            child: _segments.isEmpty
                ? Center(
                    child: Text(
                      'No segments recorded',
                      style: TextStyle(color: subtextColor),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _segments.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedIndices.contains(index);
                      final segmentPath = _segments[index];
                      final thumbnail = _thumbnails[segmentPath];
                      
                      return GestureDetector(
                        onTap: () => _toggleSelection(index),
                        onLongPress: () => _deleteSegment(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Colors.deepOrange.withOpacity(0.15)
                                : cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected 
                                  ? Colors.deepOrange 
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: Colors.deepOrange.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
                          ),
                          child: Row(
                            children: [
                              // Thumbnail
                              Container(
                                width: 80,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: thumbnail != null
                                      ? Image.memory(
                                          thumbnail,
                                          fit: BoxFit.cover,
                                          width: 80,
                                          height: 60,
                                        )
                                      : Center(
                                          child: _isLoadingThumbnails
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.deepOrange,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.videocam,
                                                  color: Colors.white54,
                                                  size: 24,
                                                ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Segment ${index + 1}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.play_circle_outline,
                                          size: 14,
                                          color: subtextColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Clip ${index + 1} of ${_segments.length}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: subtextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Selection indicator
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? Colors.deepOrange 
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected 
                                        ? Colors.deepOrange 
                                        : subtextColor,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 18,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Bottom actions
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bgColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Selected count
                  if (_segments.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${_selectedIndices.length} of ${_segments.length} segments selected',
                        style: TextStyle(
                          fontSize: 13,
                          color: subtextColor,
                        ),
                      ),
                    ),
                  
                  // Action buttons
                  Row(
                    children: [
                      // Continue Later
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onContinue,
                          icon: const Icon(Icons.access_time, size: 18),
                          label: const Text('Later'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: subtextColor,
                            side: BorderSide(color: subtextColor.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      
                      // Discard
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            showDialog(
                              context: context,
                              builder: (ctx) => Dialog(
                                backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Warning Icon
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Colors.orange.shade400, Colors.red.shade500],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red.withOpacity(0.3),
                                              blurRadius: 15,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.warning_rounded, color: Colors.white, size: 32),
                                      ),
                                      const SizedBox(height: 20),
                                      
                                      // Title
                                      Text(
                                        'Discard Recording?',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      // Message
                                      Text(
                                        'All recorded segments will be permanently deleted and cannot be recovered.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                      
                                      // Buttons
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextButton(
                                              onPressed: () => Navigator.of(ctx).pop(),
                                              style: TextButton.styleFrom(
                                                foregroundColor: isDark ? Colors.white60 : Colors.black54,
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  side: BorderSide(
                                                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                                  ),
                                                ),
                                              ),
                                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () {
                                                Navigator.of(ctx).pop();
                                                widget.onDiscard();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                elevation: 0,
                                              ),
                                              child: const Text('Discard', style: TextStyle(fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Discard'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      
                      // Finish
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _selectedIndices.isEmpty ? null : () {
                            final selectedSegments = _selectedIndices
                                .toList()
                                ..sort();
                            final result = selectedSegments.map((i) => _segments[i]).toList();
                            widget.onFinish(result);
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Finish'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

