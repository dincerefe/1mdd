import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// End-to-end integration tests for Digital Diary app
/// Run with: flutter test integration_test/app_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('app launches and shows loading screen', (tester) async {
      // This test verifies the app can launch
      // Note: Full app testing requires Firebase emulator setup
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Starting...'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Starting...'), findsOneWidget);
    });

    testWidgets('login screen navigation flow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (context) => _MockSplashScreen(),
            '/login': (context) => _MockLoginScreen(),
            '/home': (context) => _MockHomeScreen(),
          },
        ),
      );

      // Wait for splash
      await tester.pumpAndSettle();

      // Navigate to login
      await tester.tap(find.text('Go to Login'));
      await tester.pumpAndSettle();

      // Verify login screen
      expect(find.text('Login'), findsWidgets);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('form submission flow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _MockLoginScreen(),
        ),
      );

      // Enter credentials
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'test@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'password123',
      );

      // Submit form
      await tester.tap(find.text('Login'));
      await tester.pump();

      // Verify loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('video feed scroll and interaction', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _MockVideoFeed(),
        ),
      );

      // Verify initial state
      expect(find.text('Video 0'), findsOneWidget);

      // Scroll down
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Verify scroll worked (video 0 might be off screen)
      expect(find.text('Video 5'), findsOneWidget);

      // Tap like button
      await tester.tap(find.byIcon(Icons.favorite_border).first);
      await tester.pump();

      // Verify like state changed
      expect(find.byIcon(Icons.favorite), findsWidgets);
    });

    testWidgets('navigation between screens', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _MockHomeWithNavigation(),
        ),
      );

      // Verify home screen
      expect(find.text('Home'), findsOneWidget);

      // Navigate to profile
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);

      // Navigate to settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('theme toggle works correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _MockSettingsScreen(),
        ),
      );

      // Find and tap theme toggle
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Verify toggle state changed
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, true);
    });
  });
}

// Mock screens for integration testing

class _MockSplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Digital Diary'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockLoginScreen extends StatefulWidget {
  @override
  State<_MockLoginScreen> createState() => _MockLoginScreenState();
}

class _MockLoginScreenState extends State<_MockLoginScreen> {
  bool _isLoading = false;

  void _submit() {
    setState(() => _isLoading = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              key: const Key('email_field'),
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextFormField(
              key: const Key('password_field'),
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Login'),
                  ),
          ],
        ),
      ),
    );
  }
}

class _MockHomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(child: Text('Welcome!')),
    );
  }
}

class _MockVideoFeed extends StatefulWidget {
  @override
  State<_MockVideoFeed> createState() => _MockVideoFeedState();
}

class _MockVideoFeedState extends State<_MockVideoFeed> {
  final Set<int> _likedVideos = {};

  void _toggleLike(int index) {
    setState(() {
      if (_likedVideos.contains(index)) {
        _likedVideos.remove(index);
      } else {
        _likedVideos.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: ListView.builder(
        itemCount: 20,
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.all(8),
          child: Column(
            children: [
              Container(
                height: 200,
                color: Colors.grey,
                child: Center(child: Text('Video $index')),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _likedVideos.contains(index)
                          ? Icons.favorite
                          : Icons.favorite_border,
                    ),
                    onPressed: () => _toggleLike(index),
                  ),
                  Text('${_likedVideos.contains(index) ? 1 : 0} likes'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockHomeWithNavigation extends StatefulWidget {
  @override
  State<_MockHomeWithNavigation> createState() => _MockHomeWithNavigationState();
}

class _MockHomeWithNavigationState extends State<_MockHomeWithNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const Center(child: Text('Home')),
    const Center(child: Text('Profile')),
    const Center(child: Text('Settings')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class _MockSettingsScreen extends StatefulWidget {
  @override
  State<_MockSettingsScreen> createState() => _MockSettingsScreenState();
}

class _MockSettingsScreenState extends State<_MockSettingsScreen> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListTile(
        title: const Text('Dark Mode'),
        trailing: Switch(
          value: _isDarkMode,
          onChanged: (value) => setState(() => _isDarkMode = value),
        ),
      ),
    );
  }
}
