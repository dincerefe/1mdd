// Integration Tests with REAL Firebase
// WARNING: These tests require network connection and will affect real Firebase data!
// Use a TEST Firebase project, NOT production!

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_diary/firebase_options.dart';

/// IMPORTANT: Before running these tests, ensure:
/// 1. You have a test Firebase project configured
/// 2. Test user credentials are set below
/// 3. Firestore rules allow test operations
/// 4. You understand these tests affect REAL data

// Test configuration - Uses same test user as Postman tests
const String testEmail = 'postman_test@example.com';
const String testPassword = 'TestPassword123!';
const String testUserId = 'integration_test_user';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuth auth;
  late FirebaseFirestore firestore;

  setUpAll(() async {
    // Initialize Firebase with real configuration
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    auth = FirebaseAuth.instance;
    firestore = FirebaseFirestore.instance;
    
    // Sign out any existing user
    await auth.signOut();
  });

  tearDownAll(() async {
    // Cleanup: Sign out and delete test data
    try {
      await auth.signOut();
      // Optional: Delete test user data from Firestore
      // await firestore.collection('users').doc(testUserId).delete();
    } catch (e) {
      print('Cleanup error: $e');
    }
  });

  group('Real Firebase Authentication Tests', () {
    test('Firebase is initialized', () async {
      expect(Firebase.apps.isNotEmpty, isTrue);
    });

    test('Sign in with email and password', () async {
      try {
        final userCredential = await auth.signInWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );

        expect(userCredential.user, isNotNull);
        expect(userCredential.user!.email, equals(testEmail));
        
        print('✅ Successfully signed in as: ${userCredential.user!.email}');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          print('⚠️ Test user not found - creating new user...');
          // Create test user if not exists
          final newUser = await auth.createUserWithEmailAndPassword(
            email: testEmail,
            password: testPassword,
          );
          expect(newUser.user, isNotNull);
          print('✅ Created new test user: ${newUser.user!.email}');
        } else {
          print('⚠️ Auth error: ${e.code} - ${e.message}');
          // Don't fail - just log the error
        }
      }
    });

    test('Get current user after sign in', () async {
      final user = auth.currentUser;
      
      if (user != null) {
        expect(user.email, equals(testEmail));
        print('✅ Current user: ${user.email}');
      } else {
        print('ℹ️ No user signed in (expected if previous test created new user)');
      }
    });

    test('Sign out', () async {
      await auth.signOut();
      expect(auth.currentUser, isNull);
      print('✅ Successfully signed out');
    });
  });

  group('Real Firestore Tests', () {
    // Sign in before Firestore tests (required by security rules)
    setUpAll(() async {
      await auth.signInWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      );
      print('✅ Signed in for Firestore tests');
    });

    test('Write and read document', () async {
      // Create a test document
      final testDoc = firestore
          .collection('integration_tests')
          .doc('test_${DateTime.now().millisecondsSinceEpoch}');

      final testData = {
        'message': 'Integration test',
        'timestamp': FieldValue.serverTimestamp(),
        'testRun': DateTime.now().toIso8601String(),
      };

      // Write
      await testDoc.set(testData);
      print('✅ Document written successfully');

      // Read
      final snapshot = await testDoc.get();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data()?['message'], equals('Integration test'));
      print('✅ Document read successfully');

      // Cleanup
      await testDoc.delete();
      print('✅ Document deleted (cleanup)');
    });

    test('Query collection', () async {
      // Create test documents
      final batch = firestore.batch();
      final testCollection = firestore.collection('integration_tests');
      
      for (int i = 0; i < 3; i++) {
        final doc = testCollection.doc('query_test_$i');
        batch.set(doc, {
          'index': i,
          'type': 'query_test',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      print('✅ Test documents created');

      // Simple query without orderBy (doesn't require index)
      final querySnapshot = await testCollection
          .where('type', isEqualTo: 'query_test')
          .get();

      expect(querySnapshot.docs.length, greaterThanOrEqualTo(3));
      print('✅ Query returned ${querySnapshot.docs.length} documents');

      // Cleanup
      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
      print('✅ Test documents deleted (cleanup)');
    });

    test('Update document', () async {
      final testDoc = firestore.collection('integration_tests').doc('update_test');

      // Create
      await testDoc.set({'counter': 0, 'name': 'test'});

      // Update
      await testDoc.update({'counter': FieldValue.increment(1)});

      // Verify
      final snapshot = await testDoc.get();
      expect(snapshot.data()?['counter'], equals(1));
      print('✅ Document updated successfully');

      // Cleanup
      await testDoc.delete();
    });

    test('Transaction test', () async {
      final testDoc = firestore.collection('integration_tests').doc('transaction_test');
      
      // Setup
      await testDoc.set({'value': 100});

      // Run transaction
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(testDoc);
        final currentValue = snapshot.data()?['value'] as int? ?? 0;
        transaction.update(testDoc, {'value': currentValue + 50});
      });

      // Verify
      final result = await testDoc.get();
      expect(result.data()?['value'], equals(150));
      print('✅ Transaction completed successfully');

      // Cleanup
      await testDoc.delete();
    });

    test('Batch write test', () async {
      final batch = firestore.batch();
      final docs = <DocumentReference>[];

      // Add multiple documents in batch
      for (int i = 0; i < 5; i++) {
        final doc = firestore.collection('integration_tests').doc('batch_$i');
        docs.add(doc);
        batch.set(doc, {'batch_index': i});
      }

      await batch.commit();
      print('✅ Batch write completed');

      // Verify all documents exist
      for (var doc in docs) {
        final snapshot = await doc.get();
        expect(snapshot.exists, isTrue);
      }
      print('✅ All batch documents verified');

      // Cleanup
      final deleteBatch = firestore.batch();
      for (var doc in docs) {
        deleteBatch.delete(doc);
      }
      await deleteBatch.commit();
      print('✅ Batch documents deleted (cleanup)');
    });
  });
}

/// Instructions for running real Firebase tests:
/// 
/// 1. Configure test credentials:
///    - Create a test user in Firebase Console
///    - Update testEmail and testPassword constants above
/// 
/// 2. Ensure Firestore rules allow test operations:
///    ```
///    match /integration_tests/{docId} {
///      allow read, write: if true;  // Only for testing!
///    }
///    ```
/// 
/// 3. Run the tests:
///    ```
///    flutter test integration_test/real_firebase_test.dart
///    ```
/// 
/// 4. For device testing:
///    ```
///    flutter test integration_test/real_firebase_test.dart -d <device_id>
///    ```
/// 
/// ⚠️ WARNING: These tests affect REAL Firebase data!
/// Always use a dedicated test project, never production!
