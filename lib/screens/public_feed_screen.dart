import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_diary/screens/profile_screen.dart';
import 'package:digital_diary/widgets/public_video_card.dart';
import 'package:flutter/material.dart';

class PublicFeedScreen extends StatefulWidget {
  const PublicFeedScreen({super.key});

  @override
  State<PublicFeedScreen> createState() => _PublicFeedScreenState();
}

class _PublicFeedScreenState extends State<PublicFeedScreen> {
  // Key for refreshing the stream
  Key _refreshKey = UniqueKey();

  Future<void> _onRefresh() async {
    setState(() {
      _refreshKey = UniqueKey();
    });
    // Small delay for visual feedback
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Widget _buildLoadingIndicator(BuildContext context) {
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
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
              backgroundColor: isDark 
                  ? Colors.deepOrange.withOpacity(0.2) 
                  : Colors.deepOrange.withOpacity(0.1),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading videos...',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            'No videos yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No public videos in the last 24 hours',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh, color: Colors.deepOrange),
            label: const Text(
              'Refresh',
              style: TextStyle(color: Colors.deepOrange),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Calculate the timestamp for 24 hours ago
    final twentyFourHoursAgo =
        DateTime.now().subtract(const Duration(hours: 24));
    final timestamp24hAgo = Timestamp.fromDate(twentyFourHoursAgo);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Public Feed'),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : null,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: UserSearchDelegate(),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: Colors.deepOrange,
        backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
        child: StreamBuilder<QuerySnapshot>(
          key: _refreshKey,
          // Query to get public videos from the last 24 hours
          stream: FirebaseFirestore.instance
              .collection('videos')
              .where('isPublic', isEqualTo: true)
              .where('createdAt', isGreaterThanOrEqualTo: timestamp24hAgo)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingIndicator(context);
            }

            if (snapshot.hasError) {
              // This will likely be an index error at first
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error: ${snapshot.error}\n\nThis probably requires a new Firestore index. Check the debug console for a link to create it.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: _buildEmptyState(context),
                ),
              );
            }

            final videoDocs = snapshot.data!.docs;

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: videoDocs.length,
              itemBuilder: (context, index) {
                final videoData =
                    videoDocs[index].data() as Map<String, dynamic>;
                final videoId = videoDocs[index].id;
                final creatorUid = videoData['uid'] as String?;
                return PublicVideoCard(
                  key: ValueKey('${videoId}_${creatorUid}'),
                  videoData: videoData,
                  videoId: videoId,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class UserSearchDelegate extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildUserList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildUserList();
  }

  Widget _buildUserList() {
    if (query.isEmpty) {
      return const Center(child: Text('Search for users...'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: '$query\uf8ff')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                    backgroundColor: isDark
                        ? Colors.deepOrange.withOpacity(0.2)
                        : Colors.deepOrange.withOpacity(0.1),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Searching users...',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No users found.'));
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            final userId = users[index].id;
            final username = userData['username'] ?? 'Unknown';
            final profilePicUrl = userData['profilePicUrl'] as String?;

            return ListTile(
              leading: CircleAvatar(
                key: ValueKey('search_avatar_${userId}_$profilePicUrl'),
                backgroundImage: profilePicUrl != null && profilePicUrl.isNotEmpty
                    ? NetworkImage(profilePicUrl)
                    : null,
                child: profilePicUrl == null || profilePicUrl.isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(username),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(userId: userId),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

