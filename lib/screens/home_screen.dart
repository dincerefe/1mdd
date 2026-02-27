import 'package:digital_diary/screens/camera_screen.dart';
import 'package:digital_diary/screens/private_diary_screen.dart';
import 'package:digital_diary/screens/profile_screen.dart';
import 'package:digital_diary/screens/public_feed_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  int _selectedIndex = 0;
  int _previousIndex = 0;
  late final PageController _pageController;
  final Duration _navAnimationDuration = const Duration(milliseconds: 350);
  final GlobalKey<CameraScreenState> _cameraScreenKey = GlobalKey<CameraScreenState>();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    _handlePageChange(index);
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(index, duration: _navAnimationDuration, curve: Curves.easeInOut);
  }

  void _handlePageChange(int newIndex) {
    // If leaving camera screen (index 1), save state
    if (_previousIndex == 1 && newIndex != 1) {
      _cameraScreenKey.currentState?.onPageLeft();
    }
    // If returning to camera screen (index 1), resume
    else if (_previousIndex != 1 && newIndex == 1) {
      _cameraScreenKey.currentState?.onPageReturned();
    }
    _previousIndex = newIndex;
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final bool selected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        child: AnimatedContainer(
          duration: _navAnimationDuration,
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: _navAnimationDuration,
                width: selected ? 42 : 36,
                height: selected ? 42 : 36,
                decoration: BoxDecoration(
                  color: selected ? Colors.deepOrange.withOpacity(0.12) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon, 
                  color: selected 
                      ? Colors.deepOrange 
                      : (Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white70 
                          : Colors.black54),
                  size: selected ? 24 : 22,
                ),
              ),
              const SizedBox(height: 6),
              // small selected indicator
              AnimatedContainer(
                duration: _navAnimationDuration,
                width: selected ? 18 : 0,
                height: 4,
                decoration: BoxDecoration(
                  color: selected ? Colors.deepOrange : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavAvatar({required int index}) {
    final bool selected = _selectedIndex == index;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Expanded(
        child: GestureDetector(
          onTap: () => _onItemTapped(index),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: selected ? 42 : 36,
                height: selected ? 42 : 36,
                decoration: BoxDecoration(
                  color: selected ? Colors.deepOrange.withOpacity(0.12) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: const CircleAvatar(child: Icon(Icons.person, size: 18)),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: _navAnimationDuration,
                width: selected ? 18 : 0,
                height: 4,
                decoration: BoxDecoration(
                  color: selected ? Colors.deepOrange : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final profilePicUrl = userData?['profilePicUrl'];
          return GestureDetector(
            onTap: () => _onItemTapped(index),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: selected ? 42 : 36,
                  height: selected ? 42 : 36,
                  decoration: BoxDecoration(
                    color: selected ? Colors.deepOrange.withOpacity(0.12) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.deepOrange,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: CircleAvatar(
                      key: ValueKey('nav_avatar_$profilePicUrl'),
                      backgroundImage: (profilePicUrl != null && profilePicUrl.isNotEmpty) ? NetworkImage(profilePicUrl) : null,
                      child: (profilePicUrl == null || profilePicUrl.isEmpty) ? const Icon(Icons.person, size: 18) : null,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: _navAnimationDuration,
                  width: selected ? 18 : 0,
                  height: 4,
                  decoration: BoxDecoration(
                    color: selected ? Colors.deepOrange : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      extendBody: false,
      body: PageView(
        physics: _selectedIndex == 1 ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
        controller: _pageController,
        onPageChanged: (index) {
          _handlePageChange(index);
          setState(() {
            _selectedIndex = index;
          });
        },
        children: <Widget>[
          const PrivateDiaryScreen(),
          CameraScreen(key: _cameraScreenKey),
          const PublicFeedScreen(),
          // Profile as 4th page - shows current user's profile with Settings access
          ProfileScreen(userId: FirebaseAuth.instance.currentUser?.uid ?? ''),
        ],
      ),
      bottomNavigationBar: Container(
        color: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF1A1A1A)
            : Colors.white,
        child: SafeArea(
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade800
                      : Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  _buildNavItem(icon: Icons.book, label: 'My Diary', index: 0),
                  // Center item: camera, same level as others (icon-only)
                  _buildNavItem(icon: Icons.videocam, label: 'Record', index: 1),
                  _buildNavItem(icon: Icons.public, label: 'Public', index: 2),
                  // Rightmost: profile avatar - now goes to Settings page
                  _buildNavAvatar(index: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

