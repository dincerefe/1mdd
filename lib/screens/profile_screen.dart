import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_diary/screens/fullscreen_video_screen.dart';
import 'package:digital_diary/screens/settings_screen.dart';
import 'package:digital_diary/widgets/public_video_card.dart';
import 'package:digital_diary/widgets/video_player_item.dart';
import 'package:digital_diary/widgets/calendar_modal.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _videosByDate = {};
  Map<String, List<dynamic>> _markedDates = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  Future<void> _openCalendarModal() async {
    final picked = await showCalendarModal(
      context: context,
      initialSelectedDay: _selectedDay ?? DateTime.now(),
      initialDisplayedMonth: _focusedDay,
      markedDates: _markedDates,
      highlightColor: Colors.deepOrange,
      connectorColor: Colors.deepOrange.shade200,
    );

    if (picked != null) {
      setState(() {
        _selectedDay = picked;
        _focusedDay = picked;
      });
    } else {
      // "See All" was clicked
      setState(() {
        _selectedDay = null;
      });
    }
  }

  Future<void> _changeProfilePicture() async {
    // This function will only be callable if the edit button is visible.
    final imagePicker = ImagePicker();
    final XFile? pickedImage =
        await imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedImage == null) return;

    try {
      final file = File(pickedImage.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${widget.userId}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'profilePicUrl': url});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change picture: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bool isMyProfile = widget.userId == currentUserId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!userSnapshot.hasData || userSnapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: Center(child: Text('User not found.', style: TextStyle(color: isDark ? Colors.white : Colors.black))),
          );
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final profilePicUrl = userData['profilePicUrl'] as String?;
        final username = userData['username'] ?? 'Anonymous';
        final createdAt = userData['createdAt'] as Timestamp?;
        final isPremium = userData['isPremium'] == true;
        final premiumSince = userData['premiumSince'] as Timestamp?;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading: !isMyProfile, // Only show back for other profiles
            actions: [
              if (isMyProfile) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _changeProfilePicture,
                  tooltip: 'Change Profile Picture',
                ),
                IconButton(
                  icon: const Icon(Icons.settings_rounded),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                  tooltip: 'Settings',
                ),
              ],
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
            child: Column(
              children: [
                  const SizedBox(height: 20),
                  // Profile picture
                  GestureDetector(
                    onLongPress: () {
                      if (profilePicUrl != null && profilePicUrl.isNotEmpty) {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: EdgeInsets.zero,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                InteractiveViewer(
                                  child: Image.network(profilePicUrl),
                                ),
                                Positioned(
                                  top: 40,
                                  right: 20,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        key: ValueKey('profile_avatar_${widget.userId}_$profilePicUrl'),
                        radius: 50,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: profilePicUrl != null && profilePicUrl.isNotEmpty
                            ? NetworkImage(profilePicUrl)
                            : null,
                        child: profilePicUrl == null || profilePicUrl.isEmpty
                            ? Icon(Icons.person, size: 50, color: Colors.grey.shade600)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Username
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        username,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (isPremium) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.star, color: Colors.amber, size: 28),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Member since
                  if (createdAt != null)
                    Text(
                      'Member since ${DateFormat.yMMM().format(createdAt.toDate())}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  // Premium since
                  if (isPremium && premiumSince != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Premium since ${DateFormat.yMMM().format(premiumSince.toDate())}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.amber,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  
                  // Stats and Calendar Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade900 : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Stats section
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('videos')
                              .where('uid', isEqualTo: widget.userId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final allVideos = snapshot.hasData ? snapshot.data!.docs : [];
                            final publicVideos = allVideos.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return data['isPublic'] == true;
                            }).toList();
                            
                            // Group videos by date for calendar
                            _videosByDate.clear();
                            _markedDates.clear();
                            for (var doc in allVideos) {
                              final data = doc.data() as Map<String, dynamic>;
                              final timestamp = data['createdAt'] as Timestamp?;
                              if (timestamp != null) {
                                final date = DateTime(
                                  timestamp.toDate().year,
                                  timestamp.toDate().month,
                                  timestamp.toDate().day,
                                );
                                if (!_videosByDate.containsKey(date)) {
                                  _videosByDate[date] = [];
                                }
                                _videosByDate[date]!.add({
                                  'id': doc.id,
                                  ...data,
                                });
                                
                                // Mark date for calendar modal - Only show public videos
                                if (data['isPublic'] == true) {
                                  final key = DateFormat('yyyy-MM-dd').format(date);
                                  if (!_markedDates.containsKey(key)) {
                                    _markedDates[key] = [];
                                  }
                                  _markedDates[key]!.add(data);
                                }
                              }
                            }

                            // Calculate total likes
                            int totalLikes = 0;
                            for (var doc in allVideos) {
                              final data = doc.data() as Map<String, dynamic>;
                              if (data['likes'] != null) {
                                totalLikes += (data['likes'] as List).length;
                              }
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem(
                                    icon: Icons.video_library,
                                    count: allVideos.length.toString(),
                                    label: 'Videos',
                                    color: Colors.deepPurple,
                                    isDark: isDark,
                                  ),
                                  _buildStatItem(
                                    icon: Icons.public,
                                    count: publicVideos.length.toString(),
                                    label: 'Public',
                                    color: Colors.pink,
                                    isDark: isDark,
                                  ),
                                  _buildStatItem(
                                    icon: Icons.lock,
                                    count: (allVideos.length - publicVideos.length).toString(),
                                    label: 'Private',
                                    color: Colors.orange,
                                    isDark: isDark,
                                  ),
                                  _buildStatItem(
                                    icon: Icons.favorite,
                                    count: totalLikes.toString(),
                                    label: 'Likes',
                                    color: Colors.red,
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        Divider(height: 1, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                        // Calendar button
                        InkWell(
                          onTap: _openCalendarModal,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.deepOrange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.calendar_month,
                                      color: Colors.deepOrange,
                                      size: 24,
                                    ),
                                  ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Video Calendar',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedDay != null
                                            ? 'Showing: ${DateFormat.MMMd().format(_selectedDay!)}'
                                            : 'Tap to filter by date',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Section title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.deepOrange,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _selectedDay != null
                              ? 'Videos on ${DateFormat.MMMd().format(_selectedDay!)}'
                              : 'Public Videos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Videos list
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('videos')
                        .where('uid', isEqualTo: widget.userId)
                        .where('isPublic', isEqualTo: true)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, videoSnapshot) {
                      if (videoSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ));
                      }
                      if (!videoSnapshot.hasData || videoSnapshot.data!.docs.isEmpty) {
                        return Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade900 : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.video_library_outlined,
                                size: 64,
                                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Public Videos Yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Videos will appear here once shared publicly',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      var videos = videoSnapshot.data!.docs;

                      // Filter by selected date if a date is selected
                      if (_selectedDay != null) {
                        videos = videos.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final timestamp = data['createdAt'] as Timestamp?;
                          if (timestamp == null) return false;
                          
                          final videoDate = timestamp.toDate();
                          return videoDate.year == _selectedDay!.year &&
                                 videoDate.month == _selectedDay!.month &&
                                 videoDate.day == _selectedDay!.day;
                        }).toList();
                      }

                      if (videos.isEmpty && _selectedDay != null) {
                        return Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade900 : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 48,
                                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No videos on this date',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: videos.length,
                        itemBuilder: (context, index) {
                          final videoData = videos[index].data() as Map<String, dynamic>;
                          final videoId = videos[index].id;

                          return PublicVideoCard(
                            videoId: videoId,
                            videoData: videoData,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            ),
          );
        },
      );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String count,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          count,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

