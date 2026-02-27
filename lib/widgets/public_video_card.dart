import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_diary/screens/profile_screen.dart';
import 'package:digital_diary/screens/fullscreen_video_screen.dart';
import 'package:digital_diary/widgets/video_player_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PublicVideoCard extends StatefulWidget {
  // --- FIX: Added videoId as a required parameter ---
  final String videoId;
  final Map<String, dynamic> videoData;

  const PublicVideoCard({
    super.key,
    required this.videoId,
    required this.videoData,
  });
  // --- END FIX ---

  @override
  State<PublicVideoCard> createState() => _PublicVideoCardState();
}

class _PublicVideoCardState extends State<PublicVideoCard> {
  late List<String> _likes;
  late bool _isLiked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    // Initialize from the widget data
    _likes = List<String>.from(widget.videoData['likes'] ?? []);
    _likeCount = _likes.length;
    final currentUser = FirebaseAuth.instance.currentUser;
    _isLiked = currentUser != null ? _likes.contains(currentUser.uid) : false;
  }

  Future<void> _toggleLike() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Optionally show a message to log in
      return;
    }

    final videoRef =
        FirebaseFirestore.instance.collection('videos').doc(widget.videoId);

    // Optimistically update the UI
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likeCount++;
      } else {
        _likeCount--;
      }
    });

    // Update the backend
    try {
      if (_isLiked) {
        await videoRef.update({
          'likes': FieldValue.arrayUnion([currentUser.uid])
        });
      } else {
        await videoRef.update({
          'likes': FieldValue.arrayRemove([currentUser.uid])
        });
      }
    } catch (e) {
      // If the backend update fails, revert the UI change
      setState(() {
        _isLiked = !_isLiked;
        if (_isLiked) {
          _likeCount++;
        } else {
          _likeCount--;
        }
      });
      if (kDebugMode) print("Error updating likes: $e");
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to update like: ${e.toString().contains("permission") ? "Permission denied" : "Network error"}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String creatorUid = widget.videoData['uid'];
    final String username = widget.videoData['username'] ?? 'Anonymous';
    final String profilePicUrl = widget.videoData['profilePicUrl'] ?? '';
    final Timestamp? timestamp = widget.videoData['createdAt'] as Timestamp?;
    String formattedDate = 'Date not available';
    if (timestamp != null) {
      formattedDate = DateFormat.yMMMMd().format(timestamp.toDate());
    }

    String title = widget.videoData['title'] ?? 'No Title';
    if (title.length > 20) {
      title = '${title.substring(0, 20)}...';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          // Video player
          VideoPlayerItem(
            key: ValueKey('public_video_${widget.videoId}'),
            videoUrl: widget.videoData['videoUrl'],
            showControls: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullscreenVideoScreen(
                    videoUrl: widget.videoData['videoUrl'],
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
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
          // Profile photo and username at top - StreamBuilder for real-time updates
          Positioned(
            top: 12,
            left: 12,
            child: StreamBuilder<DocumentSnapshot>(
              key: ValueKey('user_stream_$creatorUid'),
              stream: FirebaseFirestore.instance.collection('users').doc(creatorUid).snapshots(),
              builder: (context, userSnapshot) {
                String displayUsername = username;
                String displayProfilePic = profilePicUrl;
                
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                  if (userData != null) {
                    displayUsername = userData['username'] ?? username;
                    final newProfilePic = userData['profilePicUrl'] ?? '';
                    // If profile pic changed, evict old image from cache
                    if (newProfilePic != displayProfilePic && displayProfilePic.isNotEmpty) {
                      imageCache.evict(displayProfilePic);
                    }
                    displayProfilePic = newProfilePic;
                  }
                }
                
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(userId: creatorUid),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        key: ValueKey('avatar_${creatorUid}_$displayProfilePic'),
                        radius: 20,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: displayProfilePic.isNotEmpty 
                            ? NetworkImage(displayProfilePic) 
                            : null,
                        onBackgroundImageError: displayProfilePic.isNotEmpty 
                            ? (exception, stackTrace) {
                                // Handle image load error silently
                              }
                            : null,
                        child: displayProfilePic.isEmpty 
                            ? const Icon(Icons.person, size: 20, color: Colors.grey) 
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          displayUsername,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Like button at right side
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        key: ValueKey<bool>(_isLiked),
                        color: _isLiked ? Colors.red : Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_likeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Title and date at bottom
          Positioned(
            left: 12,
            right: 80,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

