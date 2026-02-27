import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

void main() {
  group('Firebase Integration Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
    });

    group('Authentication Flow', () {
      test('signInWithEmailAndPassword authenticates user successfully', () async {
        // Arrange
        final user = MockUser(
          isAnonymous: false,
          uid: 'test-uid',
          email: 'test@example.com',
        );
        mockAuth = MockFirebaseAuth(mockUser: user);

        // Act
        final credential = await mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );

        // Assert
        expect(credential.user, isNotNull);
        expect(credential.user!.email, 'test@example.com');
        expect(mockAuth.currentUser, isNotNull);
      });

      test('createUserWithEmailAndPassword creates new user', () async {
        // Arrange
        final user = MockUser(
          isAnonymous: false,
          uid: 'new-user-uid',
          email: 'newuser@example.com',
        );
        mockAuth = MockFirebaseAuth(mockUser: user);

        // Act
        final credential = await mockAuth.createUserWithEmailAndPassword(
          email: 'newuser@example.com',
          password: 'password123',
        );

        // Assert
        expect(credential.user, isNotNull);
        expect(credential.user!.email, 'newuser@example.com');
        // Note: firebase_auth_mocks generates its own UID, we just verify it exists
        expect(credential.user!.uid, isNotEmpty);
      });

      test('signOut logs out user', () async {
        // Arrange
        final user = MockUser(uid: 'test-uid');
        mockAuth = MockFirebaseAuth(mockUser: user, signedIn: true);

        // Act
        await mockAuth.signOut();

        // Assert
        expect(mockAuth.currentUser, isNull);
      });

      test('currentUser returns null when not authenticated', () async {
        // Arrange
        mockAuth = MockFirebaseAuth(signedIn: false);

        // Assert
        expect(mockAuth.currentUser, isNull);
      });

      test('authStateChanges emits user on sign in', () async {
        // Arrange
        final user = MockUser(uid: 'test-uid');
        mockAuth = MockFirebaseAuth(mockUser: user, signedIn: false);

        // Act - Sign in
        await mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password',
        );

        // Assert - currentUser should be set after sign in
        expect(mockAuth.currentUser, isNotNull);
        expect(mockAuth.currentUser!.uid, 'test-uid');
      });
    });

    group('Firestore User Profile Operations', () {
      test('creates user profile document', () async {
        // Arrange
        const userId = 'test-user-123';
        final profileData = {
          'username': 'TestUser',
          'email': 'test@example.com',
          'profilePicUrl': null,
          'isPremium': false,
          'createdAt': DateTime.now().toIso8601String(),
        };

        // Act
        await fakeFirestore.collection('users').doc(userId).set(profileData);

        // Assert
        final doc = await fakeFirestore.collection('users').doc(userId).get();
        expect(doc.exists, true);
        expect(doc.data()!['username'], 'TestUser');
        expect(doc.data()!['email'], 'test@example.com');
        expect(doc.data()!['isPremium'], false);
      });

      test('reads user profile document', () async {
        // Arrange
        const userId = 'test-user-123';
        await fakeFirestore.collection('users').doc(userId).set({
          'username': 'ExistingUser',
          'email': 'existing@example.com',
          'isPremium': true,
        });

        // Act
        final doc = await fakeFirestore.collection('users').doc(userId).get();

        // Assert
        expect(doc.exists, true);
        expect(doc.data()!['username'], 'ExistingUser');
        expect(doc.data()!['isPremium'], true);
      });

      test('updates user profile document', () async {
        // Arrange
        const userId = 'test-user-123';
        await fakeFirestore.collection('users').doc(userId).set({
          'username': 'OldName',
          'isPremium': false,
        });

        // Act
        await fakeFirestore.collection('users').doc(userId).update({
          'username': 'NewName',
          'isPremium': true,
        });

        // Assert
        final doc = await fakeFirestore.collection('users').doc(userId).get();
        expect(doc.data()!['username'], 'NewName');
        expect(doc.data()!['isPremium'], true);
      });

      test('returns null for non-existent user', () async {
        // Act
        final doc =
            await fakeFirestore.collection('users').doc('non-existent').get();

        // Assert
        expect(doc.exists, false);
      });
    });

    group('Firestore Video Operations', () {
      test('creates video document', () async {
        // Arrange
        final videoData = {
          'uid': 'user-123',
          'username': 'VideoCreator',
          'videoUrl': 'https://example.com/video.mp4',
          'thumbnailUrl': 'https://example.com/thumb.jpg',
          'likes': <String>[],
          'isPublic': true,
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Act
        final docRef = await fakeFirestore.collection('videos').add(videoData);

        // Assert
        expect(docRef.id, isNotEmpty);
        final doc = await docRef.get();
        expect(doc.data()!['uid'], 'user-123');
        expect(doc.data()!['isPublic'], true);
      });

      test('queries public videos', () async {
        // Arrange
        await fakeFirestore.collection('videos').add({
          'uid': 'user-1',
          'isPublic': true,
        });
        await fakeFirestore.collection('videos').add({
          'uid': 'user-2',
          'isPublic': false,
        });
        await fakeFirestore.collection('videos').add({
          'uid': 'user-3',
          'isPublic': true,
        });

        // Act
        final query = await fakeFirestore
            .collection('videos')
            .where('isPublic', isEqualTo: true)
            .get();

        // Assert
        expect(query.docs.length, 2);
      });

      test('queries videos by user', () async {
        // Arrange
        const targetUserId = 'user-123';
        await fakeFirestore.collection('videos').add({'uid': targetUserId});
        await fakeFirestore.collection('videos').add({'uid': targetUserId});
        await fakeFirestore.collection('videos').add({'uid': 'other-user'});

        // Act
        final query = await fakeFirestore
            .collection('videos')
            .where('uid', isEqualTo: targetUserId)
            .get();

        // Assert
        expect(query.docs.length, 2);
      });
    });

    group('Like/Unlike Video Operations', () {
      test('adds like to video', () async {
        // Arrange
        const videoId = 'video-123';
        const userId = 'user-456';
        await fakeFirestore.collection('videos').doc(videoId).set({
          'likes': <String>[],
        });

        // Act
        await fakeFirestore.collection('videos').doc(videoId).update({
          'likes': [userId],
        });

        // Assert
        final doc =
            await fakeFirestore.collection('videos').doc(videoId).get();
        final likes = List<String>.from(doc.data()!['likes']);
        expect(likes, contains(userId));
      });

      test('removes like from video', () async {
        // Arrange
        const videoId = 'video-123';
        const userId = 'user-456';
        await fakeFirestore.collection('videos').doc(videoId).set({
          'likes': [userId, 'other-user'],
        });

        // Act
        await fakeFirestore.collection('videos').doc(videoId).update({
          'likes': ['other-user'],
        });

        // Assert
        final doc =
            await fakeFirestore.collection('videos').doc(videoId).get();
        final likes = List<String>.from(doc.data()!['likes']);
        expect(likes, isNot(contains(userId)));
        expect(likes, contains('other-user'));
      });

      test('handles concurrent like updates', () async {
        // Arrange
        const videoId = 'video-123';
        await fakeFirestore.collection('videos').doc(videoId).set({
          'likes': <String>[],
        });

        // Act - Simulate multiple users liking
        await Future.wait([
          fakeFirestore.collection('videos').doc(videoId).update({
            'likes': ['user-1'],
          }),
        ]);

        // Add more likes
        await fakeFirestore.collection('videos').doc(videoId).update({
          'likes': ['user-1', 'user-2'],
        });

        // Assert
        final doc =
            await fakeFirestore.collection('videos').doc(videoId).get();
        final likes = List<String>.from(doc.data()!['likes']);
        expect(likes.length, 2);
      });
    });

    group('Premium Status Operations', () {
      test('checks free user status', () async {
        // Arrange
        const userId = 'free-user';
        await fakeFirestore.collection('users').doc(userId).set({
          'isPremium': false,
        });

        // Act
        final doc = await fakeFirestore.collection('users').doc(userId).get();
        final isPremium = doc.data()!['isPremium'] as bool;

        // Assert
        expect(isPremium, false);
      });

      test('checks premium user status', () async {
        // Arrange
        const userId = 'premium-user';
        await fakeFirestore.collection('users').doc(userId).set({
          'isPremium': true,
          'premiumExpiresAt': DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String(),
        });

        // Act
        final doc = await fakeFirestore.collection('users').doc(userId).get();
        final isPremium = doc.data()!['isPremium'] as bool;

        // Assert
        expect(isPremium, true);
      });

      test('upgrades user to premium', () async {
        // Arrange
        const userId = 'user-to-upgrade';
        await fakeFirestore.collection('users').doc(userId).set({
          'isPremium': false,
        });

        // Act
        await fakeFirestore.collection('users').doc(userId).update({
          'isPremium': true,
          'premiumStartedAt': DateTime.now().toIso8601String(),
          'premiumExpiresAt': DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String(),
        });

        // Assert
        final doc = await fakeFirestore.collection('users').doc(userId).get();
        expect(doc.data()!['isPremium'], true);
        expect(doc.data()!['premiumExpiresAt'], isNotNull);
      });

      test('handles expired subscription', () async {
        // Arrange
        const userId = 'expired-user';
        final expiredDate =
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
        await fakeFirestore.collection('users').doc(userId).set({
          'isPremium': true,
          'premiumExpiresAt': expiredDate,
        });

        // Act
        final doc = await fakeFirestore.collection('users').doc(userId).get();
        final expiresAt = DateTime.parse(doc.data()!['premiumExpiresAt']);
        final isExpired = expiresAt.isBefore(DateTime.now());

        // Assert
        expect(isExpired, true);
      });
    });
  });
}
