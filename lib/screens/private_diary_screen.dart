import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_diary/widgets/video_player_item.dart';
import 'package:digital_diary/widgets/calendar_modal.dart';
import 'package:digital_diary/screens/fullscreen_video_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class PrivateDiaryScreen extends StatefulWidget {
  const PrivateDiaryScreen({super.key});

  @override
  State<PrivateDiaryScreen> createState() => _PrivateDiaryScreenState();
}

class _PrivateDiaryScreenState extends State<PrivateDiaryScreen> {
  // --- NEW: A future that completes once we have a validated user ---
  late Future<User?> _userFuture;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _userFuture = _getValidatedUser();
  }

  // Whether calendar-only mode is enabled (show only videos for selected day)
  bool _calendarFilter = false;

  // The currently selected day on the calendar
  DateTime _selectedDay = DateTime.now();
  // The month currently displayed in the calendar UI (used by modal)
  DateTime _displayedMonth = DateTime.now();
  // Cached map of videos grouped by date string (yyyy-MM-dd) for modal highlighting
  Map<String, List<Map<String, dynamic>>> _videosByDate = {};

  Widget _buildThemedLoadingIndicator() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            'Loading your memories...',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<User?> _getValidatedUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // This is the key step: it forces a token refresh and waits for it.
      await user.getIdToken(true);
      
      // Fetch premium status
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted) {
          setState(() {
            _isPremium = userDoc.data()?['isPremium'] ?? false;
          });
        }
      } catch (e) {
        print("Error fetching premium status: $e");
      }
    }
    // Return the user object after the token is guaranteed to be fresh.
    return FirebaseAuth.instance.currentUser;
  }

  Future<DateTime?> _openCalendarModal(BuildContext context) async {
    return showCalendarModal(
      context: context,
      initialSelectedDay: _selectedDay,
      initialDisplayedMonth: _displayedMonth,
      markedDates: _videosByDate,
      highlightColor: Colors.deepOrange,
      connectorColor: Colors.deepOrange.shade200,
    );
  }

  Future<void> _showEditDialog(String videoId, Map<String, dynamic> videoData) async {
    final titleController = TextEditingController(text: videoData['title'] ?? '');
    bool isPublic = videoData['isPublic'] ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_note, color: Colors.deepOrange, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Edit Video',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.title, color: Colors.deepOrange),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                  ),
                  maxLength: 100,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: Row(
                      children: [
                        Icon(
                          isPublic ? Icons.public : Icons.lock,
                          color: isPublic ? Colors.deepOrange : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPublic ? 'Public' : 'Private',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      isPublic ? 'Everyone can see this video' : 'Only you can see this video',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    value: isPublic,
                    onChanged: (value) {
                      setDialogState(() {
                        isPublic = value;
                      });
                    },
                    activeColor: Colors.deepOrange,
                    activeTrackColor: Colors.deepOrange.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: isDark ? Colors.white24 : Colors.grey.shade300),
                const SizedBox(height: 8),
                _buildActionTile(
                  icon: Icons.download_rounded,
                  iconColor: Colors.blue,
                  title: 'Download Video',
                  subtitle: 'Save to your device',
                  isDark: isDark,
                  onTap: () {
                    Navigator.of(context).pop();
                    _downloadVideo(videoData['videoUrl']);
                  },
                ),
                _buildActionTile(
                  icon: Icons.delete_rounded,
                  iconColor: Colors.red,
                  title: 'Delete Video',
                  subtitle: 'Permanently remove this video',
                  isDark: isDark,
                  onTap: () {
                    Navigator.of(context).pop();
                    _confirmDelete(videoId, videoData['videoUrl']);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white60 : Colors.black54,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _saveVideoChanges(videoId, titleController.text, isPublic);
                if (mounted) Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: iconColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadVideo(String videoUrl) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Downloading video...'),
              ],
            ),
            backgroundColor: Colors.deepOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }

      // Download file to temporary cache
      var file = await DefaultCacheManager().getSingleFile(videoUrl);
      
      // Ensure file has a video extension for Gal to recognize it
      // Old videos might be saved without extension in cache if content-type was missing
      if (!file.path.toLowerCase().endsWith('.mp4') && 
          !file.path.toLowerCase().endsWith('.mov') && 
          !file.path.toLowerCase().endsWith('.avi')) {
        
        final tempDir = await getTemporaryDirectory();
        final newPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4';
        file = await file.copy(newPath);
      }
      
      // Save to gallery using Gal
      await Gal.putVideo(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Video saved to gallery!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      print('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to download: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _saveVideoChanges(String videoId, String title, bool isPublic) async {
    try {
      // Only update title, isPublic, and add an updatedAt timestamp
      // The createdAt field is intentionally NOT modified to preserve original date
      await FirebaseFirestore.instance.collection('videos').doc(videoId).update({
        'title': title.trim(),
        'isPublic': isPublic,
        'updatedAt': FieldValue.serverTimestamp(), // Track when last edited
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Video updated successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to update: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(String videoId, String videoUrl) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Video',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red.shade400, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. Your video will be permanently deleted.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white60 : Colors.black54,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteVideo(videoId, videoUrl);
            },
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteVideo(String videoId, String videoUrl) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Deleting video...'),
              ],
            ),
            backgroundColor: Colors.deepOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }

      // Delete from Firestore
      await FirebaseFirestore.instance.collection('videos').doc(videoId).delete();

      // Delete from Storage
      try {
        final ref = FirebaseStorage.instance.refFromURL(videoUrl);
        await ref.delete();
      } catch (e) {
        print('Error deleting video file from storage: $e');
        // Continue even if storage deletion fails
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Video deleted successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to delete: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
  // --- END NEW ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'GALLERY',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade700.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(_calendarFilter ? Icons.event : Icons.calendar_today, color: isDark ? Colors.amber : null),
              onPressed: () async {
              final picked = await _openCalendarModal(context);
              setState(() {
                if (picked == null) {
                  // "See All" was selected - show all videos for the displayed month
                  _calendarFilter = true;
                  _selectedDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
                  _displayedMonth = _selectedDay;
                } else {
                  // A specific day was selected
                  _selectedDay = picked;
                  _displayedMonth = picked;
                  _calendarFilter = true;
                }
              });
            },
            tooltip: _calendarFilter ? 'Show all videos' : 'Open calendar',
          ),
          ),
        ],
      ),
      // --- MODIFIED: Use a FutureBuilder to wait for the user ---
      body: FutureBuilder<User?>(
        future: _userFuture,
        builder: (context, userSnapshot) {
          // While waiting for the user validation, show a loading spinner.
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return _buildThemedLoadingIndicator();
          }

          // If there's no user data after waiting, show a message.
          if (!userSnapshot.hasData || userSnapshot.data == null) {
            return const Center(
                child: Text("Not logged in. Please restart the app."));
          }

          // Once we have a validated user, we can build the list.
          final user = userSnapshot.data!;

          // This StreamBuilder will now only run AFTER the user is validated.
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('videos')
                .where('uid', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildThemedLoadingIndicator();
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.video_library_outlined,
                        size: 80,
                        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Your Journey Begins Here",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Start recording your memories",
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final videoDocs = snapshot.data!.docs;

              // Group videos by local date (yyyy-MM-dd)
              final Map<String, List<Map<String, dynamic>>> videosByDate = {};
              for (final doc in videoDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final ts = data['createdAt'] as Timestamp? ?? Timestamp.now();
                final date = ts.toDate();
                final key = DateFormat('yyyy-MM-dd').format(date);
                videosByDate.putIfAbsent(key, () => []).add(data);
              }

              // Cache group for modal calendar highlighting/streaks
              _videosByDate = videosByDate;

              

              // If calendar filter is disabled, show full list latest->oldest
              if (!_calendarFilter) {
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: videoDocs.length,
                  itemBuilder: (context, index) {
                    final videoDoc = videoDocs[index];
                    final videoId = videoDoc.id;
                    final videoData = videoDoc.data() as Map<String, dynamic>;
                    final Timestamp timestamp = videoData['createdAt'] ?? Timestamp.now();
                    final date = timestamp.toDate();
                    final formattedDate = DateFormat.yMMMMd().add_jm().format(date);
                    final isPublic = videoData['isPublic'] ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                      clipBehavior: Clip.antiAlias,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Stack(
                        children: [
                          VideoPlayerItem(
                            key: ValueKey(videoId),
                            videoUrl: videoData['videoUrl'],
                            showControls: false,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullscreenVideoScreen(
                                    videoUrl: videoData['videoUrl'],
                                  ),
                                ),
                              );
                            },
                          ),
                          // Gradient overlay at bottom
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                          ),
                          // Edit button at top right
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                                onPressed: () => _showEditDialog(videoId, videoData),
                                tooltip: 'Edit video',
                              ),
                            ),
                          ),
                          // Public indicator
                          if (isPublic)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.public, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Public',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Title and date at bottom
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  videoData['title'] ?? 'No Title',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }

              // When calendar filter is active we show videos for selected day or month
              if (_calendarFilter) {
                final startDate = DateTime(_selectedDay.year, _selectedDay.month, 1);
                final endDate = DateTime(_selectedDay.year, _selectedDay.month + 1, 0);

                // Filter videos for the selected day or month
                final filteredVideos = videoDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final ts = data['createdAt'] as Timestamp? ?? Timestamp.now();
                  final date = ts.toDate();
                  
                  if (DateFormat('yyyy-MM-dd').format(_selectedDay) == 
                      DateFormat('yyyy-MM-dd').format(startDate)) {
                    // If selected day is first of month, show all videos for month
                    return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
                           date.isBefore(endDate.add(const Duration(days: 1)));
                  } else {
                    // Show videos for specific day
                    return DateFormat('yyyy-MM-dd').format(date) == 
                           DateFormat('yyyy-MM-dd').format(_selectedDay);
                  }
                }).toList();

                if (filteredVideos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          DateFormat('yyyy-MM-dd').format(_selectedDay) == 
                          DateFormat('yyyy-MM-dd').format(startDate)
                              ? 'No videos for ${DateFormat.yMMMM().format(_selectedDay)}'
                              : 'No videos for ${DateFormat.yMMMMd().format(_selectedDay)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: filteredVideos.length,
                  itemBuilder: (context, index) {
                    final videoDoc = filteredVideos[index];
                    final videoId = videoDoc.id;
                    final videoData = videoDoc.data() as Map<String, dynamic>;
                    final Timestamp timestamp = videoData['createdAt'] ?? Timestamp.now();
                    final formattedDate = DateFormat.yMMMMd().add_jm().format(timestamp.toDate());
                    final isPublic = videoData['isPublic'] ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                      clipBehavior: Clip.antiAlias,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Stack(
                        children: [
                          VideoPlayerItem(
                            key: ValueKey(videoId),
                            videoUrl: videoData['videoUrl'],
                            showControls: false,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullscreenVideoScreen(
                                    videoUrl: videoData['videoUrl'],
                                  ),
                                ),
                              );
                            },
                          ),
                          // Gradient overlay at bottom
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                          ),
                          // Edit button at top right
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                                onPressed: () => _showEditDialog(videoId, videoData),
                                tooltip: 'Edit video',
                              ),
                            ),
                          ),
                          // Public indicator
                          if (isPublic)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.public, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Public',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Title and date at bottom
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isPublic && videoData['likes'] != null) ...[
                                      const Icon(Icons.favorite, color: Colors.red, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${(videoData['likes'] as List).length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  videoData['title'] ?? 'No Title',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }

              // Default: full list latest->oldest (handled above), but keep fallback
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                itemCount: videoDocs.length,
                itemBuilder: (context, index) {
                  final videoDoc = videoDocs[index];
                  final videoId = videoDoc.id;
                  final videoData = videoDoc.data() as Map<String, dynamic>;
                  final Timestamp timestamp = videoData['createdAt'] ?? Timestamp.now();
                  final date = timestamp.toDate();
                  final formattedDate = DateFormat.yMMMMd().add_jm().format(date);
                  final isPublic = videoData['isPublic'] ?? false;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                    clipBehavior: Clip.antiAlias,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Stack(
                      children: [
                        VideoPlayerItem(
                          key: ValueKey(videoId),
                          videoUrl: videoData['videoUrl'],
                          showControls: false,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullscreenVideoScreen(
                                  videoUrl: videoData['videoUrl'],
                                ),
                              ),
                            );
                          },
                        ),
                        // Gradient overlay at bottom
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                          ),
                        ),
                        // Edit button at top right
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                              onPressed: () => _showEditDialog(videoId, videoData),
                              tooltip: 'Edit video',
                            ),
                          ),
                        ),
                        // Public indicator
                        if (isPublic)
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.public, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Public',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Title and date at bottom
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isPublic && videoData['likes'] != null) ...[
                                    const Icon(Icons.favorite, color: Colors.red, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(videoData['likes'] as List).length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                videoData['title'] ?? 'No Title',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      // --- END MODIFICATION ---
    );
  }
}

