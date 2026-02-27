import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_diary/widgets/video_player_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';

enum _UploadStage { compressing, uploading, finalizing }

enum _SnackBarKind { success, error, info }

class SaveVideoScreen extends StatefulWidget {
  final File videoFile;
  const SaveVideoScreen({super.key, required this.videoFile});

  @override
  State<SaveVideoScreen> createState() => _SaveVideoScreenState();
}

class _SaveVideoScreenState extends State<SaveVideoScreen> {
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPublic = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  UploadTask? _uploadTask;
  String _selectedEmotion = '😊'; // Default emotion

  _UploadStage _uploadStage = _UploadStage.compressing;

  late final Future<bool> _videoExistsFuture;

  @override
  void initState() {
    super.initState();
    // Cache this so typing (setState) doesn't restart the FutureBuilder and flicker the video.
    _videoExistsFuture = widget.videoFile.exists();
  }

  // Available emotions
  final List<Map<String, String>> _emotions = [
    {'emoji': '😊', 'label': 'Happy'},
    {'emoji': '😢', 'label': 'Sad'},
    {'emoji': '😍', 'label': 'Love'},
    {'emoji': '😎', 'label': 'Cool'},
    {'emoji': '😴', 'label': 'Tired'},
    {'emoji': '😡', 'label': 'Angry'},
    {'emoji': '🤔', 'label': 'Thoughtful'},
    {'emoji': '🎉', 'label': 'Excited'},
    {'emoji': '😌', 'label': 'Peaceful'},
    {'emoji': '🥳', 'label': 'Celebrate'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _showStatusSnackBar({
    required String message,
    required _SnackBarKind kind,
  }) {
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color background;
    final IconData icon;

    switch (kind) {
      case _SnackBarKind.success:
        background = Colors.green.shade700;
        icon = Icons.check_circle_outline;
        break;
      case _SnackBarKind.error:
        background = Colors.red.shade700;
        icon = Icons.error_outline;
        break;
      case _SnackBarKind.info:
        background = isDark ? Colors.grey.shade800 : Colors.grey.shade900;
        icon = Icons.info_outline;
        break;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: background,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(milliseconds: 1400),
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _uploadVideo() async {
    print("--- UPLOAD PROCESS STARTED ---");
    if (!_formKey.currentState!.validate()) {
      print("[DEBUG] Form validation failed.");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("[DEBUG] ERROR: User is not logged in.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Error: You are not logged in.')),
      );
      return;
    }
    final currentUserId = user.uid;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStage = _UploadStage.compressing;
    });

    try {
      // 1. COMPRESSION
      print("[DEBUG] Step 1: Starting video compression...");
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        widget.videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );

      if (mediaInfo == null || mediaInfo.path == null) {
        throw Exception('Video compression returned null.');
      }
      final compressedFile = File(mediaInfo.path!);
      final fileSize = await compressedFile.length();
      print("[DEBUG] Step 1 COMPLETE: Compression finished. New file size: $fileSize bytes");

      if (mounted) {
        setState(() {
          _uploadStage = _UploadStage.uploading;
          _uploadProgress = 0.0;
        });
      }

      // 2. UPLOAD TO FIREBASE STORAGE
      print("[DEBUG] Step 2: Preparing to upload to Firebase Storage...");
      final storageRef = FirebaseStorage.instance.ref();
      final videosRef = storageRef.child(
          'videos/$currentUserId/${DateTime.now().millisecondsSinceEpoch}.mp4');

      _uploadTask = videosRef.putFile(compressedFile);
      print("[DEBUG] Step 2 IN PROGRESS: Upload task started.");

      _uploadTask!.snapshotEvents.listen((taskSnapshot) {
        final progress = taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
        setState(() {
          _uploadProgress = progress;
        });
      });

      final snapshot = await _uploadTask!;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print("[DEBUG] Step 2 COMPLETE: File uploaded. Download URL: $downloadUrl");

      if (mounted) {
        setState(() {
          _uploadStage = _UploadStage.finalizing;
        });
      }

      // 3. GET USER DATA
      print("[DEBUG] Step 3: Fetching user data from Firestore...");
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      final username = userDoc.data()?['username'] ?? 'Anonymous';
      final profilePicUrl = userDoc.data()?['profilePicUrl'] ?? '';
      print("[DEBUG] Step 3 COMPLETE: Fetched user data.");

      // 4. SAVE TO FIRESTORE
      print("[DEBUG] Step 4: Saving video metadata to Firestore...");
      await FirebaseFirestore.instance.collection('videos').add({
        'uid': currentUserId,
        'username': username,
        'profilePicUrl': profilePicUrl,
        'title': _titleController.text,
        'videoUrl': downloadUrl,
        'isPublic': _isPublic,
        'emotion': _selectedEmotion,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
      });
      print("[DEBUG] Step 4 COMPLETE: Firestore document created.");
      print("--- UPLOAD PROCESS SUCCEEDED ---");

      if (!mounted) return;
      _showStatusSnackBar(message: 'Video uploaded successfully!', kind: _SnackBarKind.success);
      // Let the user actually see the feedback before popping this route.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      print("[DEBUG] AN ERROR OCCURRED: $e");
      print("--- UPLOAD PROCESS FAILED ---");
      setState(() {
        _isUploading = false;
        _uploadTask = null;
        _uploadStage = _UploadStage.compressing;
      });
      if (mounted) {
        _showStatusSnackBar(message: 'Upload failed: ${e.toString()}', kind: _SnackBarKind.error);
      }
    }
  }

  void _cancelUpload() {
    // Best-effort cancellation for both compression and upload.
    try {
      VideoCompress.cancelCompression();
    } catch (_) {
      // ignore
    }
    _uploadTask?.cancel();
    setState(() {
      _isUploading = false;
      _uploadTask = null;
      _uploadStage = _UploadStage.compressing;
      _uploadProgress = 0.0;
    });

    _showStatusSnackBar(message: 'Upload cancelled.', kind: _SnackBarKind.info);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.grey.shade100;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white.withOpacity(0.6) : Colors.black54;
    final cardColor = isDark ? Colors.white.withOpacity(0.08) : Colors.white;
    final cardBorderColor = isDark ? Colors.deepOrange.withOpacity(0.3) : Colors.grey.shade300;
    
    return PopScope(
      canPop: !_isUploading,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_isUploading) {
          Navigator.pop(context, false);
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Save Your Diary',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: textColor),
            onPressed: _isUploading ? null : () => Navigator.pop(context, false),
          ),
        ),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Video Preview with rounded corners
              Container(
                height: 350,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepOrange.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _buildVideoPreview(),
                ),
              ),
              const SizedBox(height: 28),
              
              // Title Input with character counter
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: cardColor,
                  border: Border.all(
                    color: cardBorderColor,
                    width: 1,
                  ),
                  boxShadow: isDark ? null : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      maxLength: 50,
                      style: TextStyle(color: textColor, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Give your memory a title',
                        labelStyle: TextStyle(color: subtextColor),
                        prefixIcon: Icon(
                          Icons.edit_note_rounded,
                          color: Colors.deepOrange.withOpacity(0.8),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                        hintText: 'What happened today?',
                        hintStyle: TextStyle(color: subtextColor.withOpacity(0.5)),
                        counterText: '',
                      ),
                      onChanged: (value) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 0),
                      child: Text(
                        '${_titleController.text.length}/50',
                        style: TextStyle(
                          fontSize: 12,
                          color: _titleController.text.length >= 50 
                              ? Colors.red 
                              : subtextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Visibility Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: cardColor,
                  border: Border.all(
                    color: cardBorderColor,
                    width: 1,
                  ),
                  boxShadow: isDark ? null : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visibility',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Private option
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isPublic = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: !_isPublic 
                                    ? Colors.deepOrange.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: !_isPublic 
                                      ? Colors.deepOrange
                                      : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    color: !_isPublic ? Colors.deepOrange : subtextColor,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Private',
                                    style: TextStyle(
                                      color: !_isPublic ? Colors.deepOrange : textColor,
                                      fontWeight: !_isPublic ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Only you',
                                    style: TextStyle(
                                      color: subtextColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Public option
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isPublic = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: _isPublic 
                                    ? Colors.deepOrange.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isPublic 
                                      ? Colors.deepOrange
                                      : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.public,
                                    color: _isPublic ? Colors.deepOrange : subtextColor,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Public',
                                    style: TextStyle(
                                      color: _isPublic ? Colors.deepOrange : textColor,
                                      fontWeight: _isPublic ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Everyone',
                                    style: TextStyle(
                                      color: subtextColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Emotion Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How are you feeling?',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _emotions.length,
                        itemBuilder: (context, index) {
                          final emotion = _emotions[index];
                          final isSelected = _selectedEmotion == emotion['emoji'];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedEmotion = emotion['emoji'] as String;
                              });
                            },
                            child: Container(
                              width: 70,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.deepOrange.withOpacity(0.15)
                                    : (isDark ? Colors.grey[850] : Colors.grey[100]),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.deepOrange
                                      : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    emotion['emoji'] as String,
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    emotion['label'] as String,
                                    style: TextStyle(
                                      color: isSelected ? Colors.deepOrange : subtextColor,
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Upload Section
              if (_isUploading)
                _buildUploadingUI(isDark, textColor, subtextColor)
              else
                _buildUploadButton(),
            ],
          ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildVideoPreview() {
    return FutureBuilder<bool>(
      future: _videoExistsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.deepOrange),
          );
        }
        
        if (snapshot.data != true) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_off, size: 48, color: Colors.grey.shade600),
                const SizedBox(height: 8),
                Text(
                  'Video not found',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }
        
        return VideoPlayerItem(
          videoUrl: widget.videoFile.path,
          isLocalFile: true,
          showControls: true,
        );
      },
    );
  }

  Widget _buildUploadingUI(bool isDark, Color textColor, Color subtextColor) {
    final String statusText;
    switch (_uploadStage) {
      case _UploadStage.compressing:
        statusText = 'Compressing video...';
        break;
      case _UploadStage.uploading:
        statusText = 'Uploading your memory...';
        break;
      case _UploadStage.finalizing:
        statusText = 'Finalizing...';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepOrange.withOpacity(isDark ? 0.15 : 0.1),
            Colors.orange.withOpacity(isDark ? 0.1 : 0.05),
          ],
        ),
        border: Border.all(
          color: Colors.deepOrange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Animated upload icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 2),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -5 * (1 - value)),
                child: Icon(
                  Icons.cloud_upload_rounded,
                  size: 50,
                  color: Colors.deepOrange.withOpacity(0.8 + (value * 0.2)),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          
          // Progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
            child: _uploadStage == _UploadStage.compressing
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      color: Colors.deepOrange,
                      backgroundColor: Colors.transparent,
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: constraints.maxWidth * _uploadProgress,
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
          
          // Percentage
          if (_uploadStage == _UploadStage.uploading)
            Text(
              '${(_uploadProgress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            )
          else
            const SizedBox(height: 28),
          const SizedBox(height: 8),
          
          Text(
            statusText,
            style: TextStyle(
              fontSize: 14,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 20),
          
          // Cancel button
          TextButton.icon(
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Cancel Upload', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            onPressed: _cancelUpload,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade400,
              backgroundColor: Colors.red.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.deepOrange,
            Colors.deepOrange.shade700,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _uploadVideo,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.cloud_upload_rounded, size: 24, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Save & Upload',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}