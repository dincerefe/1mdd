import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_diary/main.dart';
import 'package:digital_diary/screens/premium_screen.dart';
import 'package:digital_diary/services/local_notification_service.dart';
import 'package:digital_diary/services/video_segment_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image_picker/image_picker.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Navigate to Premium Screen
  void _openPremiumScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PremiumScreen()),
    );
  }

  // --- Profile Picture Logic ---
  Future<void> _changeProfilePicture() async {
    final imagePicker = ImagePicker();
    final XFile? pickedImage =
        await imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedImage == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not found");

      final file = File(pickedImage.path);
      final ref = _storage.ref().child('profile_pictures').child('${user.uid}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await _firestore.collection('users').doc(user.uid).update({
        'profilePicUrl': url,
      });

      if (mounted) {
        _showSuccessSnackBar('Profile picture updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to update profile picture: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Username Logic ---
  void _showChangeUsernameDialog() {
    final usernameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_outline, color: Colors.deepOrange, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Change Username',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: usernameController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: 'New Username',
              labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              prefixIcon: const Icon(Icons.edit, color: Colors.deepOrange),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
              ),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
            ),
            validator: (value) {
              if (value == null || value.trim().length < 4) {
                return 'Username must be at least 4 characters long.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white60 : Colors.black54,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop();
                _updateUsername(usernameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUsername(String newUsername) async {
    setState(() { _isLoading = true; });
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not found");

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({'username': newUsername});

      if (mounted) {
        _showSuccessSnackBar('Username updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to update username: $e');
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  // --- Change Email Logic ---
  void _showChangeEmailDialog() {
    final passwordController = TextEditingController();
    final newEmailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.email_outlined, color: Colors.deepOrange, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Change Email',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: newEmailController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'New Email',
                  labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                  prefixIcon: const Icon(Icons.mail, color: Colors.deepOrange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => (value == null || !value.contains('@'))
                    ? 'Please enter a valid email.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.deepOrange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                ),
                obscureText: true,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Please enter your password.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white60 : Colors.black54,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop();
                _changeEmail(passwordController.text, newEmailController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _changeEmail(String password, String newEmail) async {
    setState(() { _isLoading = true; });
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) throw Exception("User not found");

      final cred = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);
      await user.verifyBeforeUpdateEmail(newEmail);

      if(mounted) {
        _showSuccessSnackBar('Verification email sent to $newEmail.');
      }
    } on FirebaseAuthException catch (e) {
       if (mounted) {
         _showErrorSnackBar(e.message ?? 'An error occurred.');
       }
    } catch (e) {
      if(mounted) {
        _showErrorSnackBar('An unexpected error occurred.');
      }
    } finally {
      if (mounted) { setState(() { _isLoading = false; });}
    }
  }

  // --- Change Password Logic ---
  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_outline, color: Colors.deepOrange, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Change Password',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldPasswordController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                  prefixIcon: const Icon(Icons.lock, color: Colors.deepOrange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                ),
                obscureText: true,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: newPasswordController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                  prefixIcon: const Icon(Icons.lock_open, color: Colors.deepOrange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                ),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6) ? 'Must be at least 6 characters' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPasswordController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                  prefixIcon: const Icon(Icons.check_circle_outline, color: Colors.deepOrange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                ),
                obscureText: true,
                validator: (v) => (v != newPasswordController.text) ? 'Passwords do not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white60 : Colors.black54,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop();
                _changePassword(oldPasswordController.text, newPasswordController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            child: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(String oldPassword, String newPassword) async {
    setState(() { _isLoading = true; });
    try {
       final user = _auth.currentUser;
       if (user == null || user.email == null) throw Exception("User not found");

       final cred = EmailAuthProvider.credential(email: user.email!, password: oldPassword);
       await user.reauthenticateWithCredential(cred);
       await user.updatePassword(newPassword);

       if(mounted) {
         _showSuccessSnackBar('Password updated successfully.');
       }

    } on FirebaseAuthException catch (e) {
      if(mounted) {
        _showErrorSnackBar(e.message ?? 'An error occurred.');
      }
    } catch (e) {
      if(mounted) {
        _showErrorSnackBar('An unexpected error occurred.');
      }
    } finally {
      if(mounted) { setState(() { _isLoading = false; }); }
    }
  }


  // --- Delete Account Logic ---
  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              'Delete Account',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
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
                      'This action is permanent and cannot be undone. All your videos and data will be deleted forever.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Enter your password to confirm',
                labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                prefixIcon: const Icon(Icons.lock_outline, color: Colors.red),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white60 : Colors.black54,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteAccount(passwordController.text);
            },
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(String password) async {
    setState(() { _isLoading = true; });
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) throw Exception("User not found");
      
      final cred = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);
      
      // Delete all user's videos from Firestore
      final videosSnapshot = await _firestore
          .collection('videos')
          .where('uid', isEqualTo: user.uid)
          .get();
      
      for (var doc in videosSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // Delete all user's video files from Firebase Storage
      try {
        final storageRef = _storage.ref().child('videos/${user.uid}');
        final listResult = await storageRef.listAll();
        
        for (var item in listResult.items) {
          await item.delete();
        }
      } catch (e) {
        // Continue even if storage deletion fails (folder might not exist)
        print('Storage deletion error: $e');
      }
      
      // Delete profile picture from Storage
      try {
        final profilePicRef = _storage.ref().child('profile_pictures/${user.uid}.jpg');
        await profilePicRef.delete();
      } catch (e) {
        // Continue even if profile picture deletion fails (might not exist)
        print('Profile picture deletion error: $e');
      }
      
      // Delete user document from Firestore
      await _firestore.collection('users').doc(user.uid).delete();
      
      // Delete Firebase Auth account
      await user.delete();

      if(mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        _showSuccessSnackBar('Account deleted successfully.');
      }

    } on FirebaseAuthException catch (e) {
      if(mounted) {
        _showErrorSnackBar(e.message ?? 'An error occurred.');
      }
    } catch(e) {
      if(mounted) {
        _showErrorSnackBar('An unexpected error occurred: $e');
      }
    } finally {
      if(mounted) { setState(() { _isLoading = false; }); }
    }
  }

  void _showSignOutDialog() {
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
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.deepOrange, Colors.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepOrange.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Sign Out?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                'Your unsaved recordings will be cleared. You can sign in again anytime.',
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
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        
                        // Clear video segments and cache
                        try {
                          final segmentService = VideoSegmentService();
                          await segmentService.clearSession();
                          
                          // Clear flutter cache manager cache
                          await DefaultCacheManager().emptyCache();
                        } catch (e) {
                          print('Error clearing cache on sign out: $e');
                        }
                        
                        // Sign out
                        await FirebaseAuth.instance.signOut();
                        
                        if (mounted) {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
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


  // --- Helper and SnackBar Functions ---
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.error_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: Stack(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: user != null ? _firestore.collection('users').doc(user.uid).snapshots() : null,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !_isLoading) {
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
                        'Loading settings...',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              final userData = snapshot.data?.data() as Map<String, dynamic>?;
              final bool isPremium = userData?['isPremium'] ?? false;

              return ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: const Text('Change Profile Picture'),
                    onTap: _changeProfilePicture,
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Change Username'),
                    onTap: _showChangeUsernameDialog,
                  ),
                  const Divider(),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (context, currentMode, child) {
                      // Determine if switch should be on based on current mode
                      // If system, we check platform brightness. If dark, we check explicit dark mode.
                      final isDark = currentMode == ThemeMode.dark || 
                          (currentMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
                      
                      return SwitchListTile(
                        secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                        title: const Text('Dark Mode'),
                        value: isDark,
                        onChanged: (val) async {
                          final newMode = val ? ThemeMode.dark : ThemeMode.light;
                          themeNotifier.value = newMode;
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('isDarkMode', val);
                        },
                      );
                    },
                  ),
                  const Divider(),
                  if(isPremium)
                    ListTile(
                      leading: const Icon(Icons.star, color: Colors.amber),
                      title: const Text('Premium Member'),
                      subtitle: const Text('Manage your subscription'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openPremiumScreen,
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.star_outline),
                      title: const Text('Go Premium'),
                      subtitle: const Text('Unlock 5-minute videos and more features'),
                      onTap: _openPremiumScreen,
                    ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Change Email'),
                    onTap: _showChangeEmailDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock),
                    title: const Text('Change Password'),
                    onTap: _showChangePasswordDialog,
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.delete_forever, color: Colors.red.shade700),
                    title: Text(
                      'Delete Account',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                    onTap: _showDeleteAccountDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.deepOrange),
                    title: const Text('Sign Out'),
                    onTap: () => _showSignOutDialog(),
                  ),
                ],
              );
            }
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade900
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepOrange.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                          backgroundColor: Colors.deepOrange.withOpacity(0.2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Please wait...',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }
}

