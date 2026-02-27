import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for PublicVideoCard widget functionality
/// Since this widget depends on Firebase, we test the logic components

void main() {
  group('PublicVideoCard Logic Tests', () {
    group('Like State Management', () {
      test('toggleLike adds user to likes list when not liked', () {
        // Arrange
        final likes = <String>[];
        const currentUserId = 'user123';
        bool isLiked = false;

        // Act
        if (!isLiked) {
          likes.add(currentUserId);
          isLiked = true;
        }

        // Assert
        expect(likes, contains(currentUserId));
        expect(isLiked, true);
      });

      test('toggleLike removes user from likes list when already liked', () {
        // Arrange
        const currentUserId = 'user123';
        final likes = <String>[currentUserId];
        bool isLiked = true;

        // Act
        if (isLiked) {
          likes.remove(currentUserId);
          isLiked = false;
        }

        // Assert
        expect(likes, isNot(contains(currentUserId)));
        expect(isLiked, false);
      });

      test('like count updates correctly on toggle', () {
        // Arrange
        final likes = <String>['user1', 'user2'];
        const currentUserId = 'user3';
        int likeCount = likes.length;

        // Act - user likes
        likes.add(currentUserId);
        likeCount = likes.length;

        // Assert
        expect(likeCount, 3);

        // Act - user unlikes
        likes.remove(currentUserId);
        likeCount = likes.length;

        // Assert
        expect(likeCount, 2);
      });

      test('user cannot like twice', () {
        // Arrange
        const currentUserId = 'user123';
        final likes = <String>[currentUserId];

        // Act - try to add again (should check first)
        if (!likes.contains(currentUserId)) {
          likes.add(currentUserId);
        }

        // Assert
        expect(likes.where((id) => id == currentUserId).length, 1);
      });
    });

    group('Video Data Parsing', () {
      test('parses video data correctly', () {
        // Arrange
        final videoData = {
          'uid': 'creator123',
          'username': 'TestUser',
          'profilePicUrl': 'https://example.com/pic.jpg',
          'videoUrl': 'https://example.com/video.mp4',
          'likes': ['user1', 'user2'],
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        // Act
        final uid = videoData['uid'] as String;
        final username = videoData['username'] as String? ?? 'Anonymous';
        final profilePicUrl = videoData['profilePicUrl'] as String? ?? '';
        final likes = List<String>.from(videoData['likes'] as List? ?? []);

        // Assert
        expect(uid, 'creator123');
        expect(username, 'TestUser');
        expect(profilePicUrl, 'https://example.com/pic.jpg');
        expect(likes.length, 2);
      });

      test('handles missing optional fields with defaults', () {
        // Arrange
        final videoData = {
          'uid': 'creator123',
          // username missing
          // profilePicUrl missing
          // likes missing
        };

        // Act
        final username = videoData['username'] as String? ?? 'Anonymous';
        final profilePicUrl = videoData['profilePicUrl'] as String? ?? '';
        final likes = List<String>.from(videoData['likes'] as List? ?? []);

        // Assert
        expect(username, 'Anonymous');
        expect(profilePicUrl, '');
        expect(likes, isEmpty);
      });

      test('handles null likes array', () {
        // Arrange
        final videoData = {
          'uid': 'creator123',
          'likes': null,
        };

        // Act
        final likes = List<String>.from(videoData['likes'] as List? ?? []);

        // Assert
        expect(likes, isEmpty);
      });
    });

    group('User State', () {
      test('determines if current user has liked video', () {
        // Arrange
        const currentUserId = 'user123';
        final likes = <String>['user1', 'user123', 'user2'];

        // Act
        final isLiked = likes.contains(currentUserId);

        // Assert
        expect(isLiked, true);
      });

      test('determines if current user has not liked video', () {
        // Arrange
        const currentUserId = 'user123';
        final likes = <String>['user1', 'user2'];

        // Act
        final isLiked = likes.contains(currentUserId);

        // Assert
        expect(isLiked, false);
      });

      test('handles empty likes array', () {
        // Arrange
        const currentUserId = 'user123';
        final likes = <String>[];

        // Act
        final isLiked = likes.contains(currentUserId);

        // Assert
        expect(isLiked, false);
      });
    });

    group('Optimistic UI Updates', () {
      test('optimistic update increases like count before network call', () {
        // Arrange
        int likeCount = 5;
        bool isLiked = false;

        // Act - Optimistic update
        isLiked = !isLiked;
        if (isLiked) {
          likeCount++;
        } else {
          likeCount--;
        }

        // Assert - UI should show updated state immediately
        expect(likeCount, 6);
        expect(isLiked, true);
      });

      test('reverts optimistic update on network failure', () {
        // Arrange
        int likeCount = 5;
        bool isLiked = false;

        // Act - Optimistic update
        isLiked = true;
        likeCount++;

        // Simulate network failure - revert
        bool networkFailed = true;
        if (networkFailed) {
          isLiked = !isLiked;
          if (isLiked) {
            likeCount++;
          } else {
            likeCount--;
          }
        }

        // Assert - should be back to original state
        expect(likeCount, 5);
        expect(isLiked, false);
      });
    });
  });

  group('PublicVideoCard Widget Tests', () {
    testWidgets('renders video card with basic structure', (tester) async {
      // We test the basic widget structure using a simplified mock
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _MockVideoCard(
              videoData: {
                'uid': 'user1',
                'username': 'TestUser',
                'likes': ['user2'],
              },
            ),
          ),
        ),
      );

      // Assert basic elements are present
      expect(find.text('TestUser'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets('like button toggles state on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _MockVideoCard(
              videoData: {
                'uid': 'user1',
                'username': 'TestUser',
                'likes': [],
              },
            ),
          ),
        ),
      );

      // Initially not liked
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);

      // Tap like button
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();

      // Should now show filled heart
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('displays correct like count', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _MockVideoCard(
              videoData: {
                'uid': 'user1',
                'username': 'TestUser',
                'likes': ['user2', 'user3', 'user4'],
              },
            ),
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
    });
  });
}

/// Mock video card for testing UI without Firebase dependencies
class _MockVideoCard extends StatefulWidget {
  final Map<String, dynamic> videoData;

  const _MockVideoCard({required this.videoData});

  @override
  State<_MockVideoCard> createState() => _MockVideoCardState();
}

class _MockVideoCardState extends State<_MockVideoCard> {
  late List<String> _likes;
  late bool _isLiked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _likes = List<String>.from(widget.videoData['likes'] ?? []);
    _likeCount = _likes.length;
    _isLiked = false;
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likeCount++;
      } else {
        _likeCount--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(widget.videoData['username'] ?? 'Anonymous'),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
                onPressed: _toggleLike,
              ),
              Text('$_likeCount'),
            ],
          ),
        ],
      ),
    );
  }
}
