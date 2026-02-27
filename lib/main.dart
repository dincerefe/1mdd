import 'package:camera/camera.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/local_notification_service.dart';
import 'services/permission_service.dart';
import 'services/payment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// A global variable to hold the list of available cameras.
List<CameraDescription> cameras = [];

// Global theme notifier
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

Future<void> main() async {
  // Ensure all Flutter bindings are initialized before doing async work.
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  print("🔍 ENV CHECK: API_KEY present? ${dotenv.env['ANDROID_API_KEY'] != null}");
  print("🔍 ENV CHECK: Bucket: ${dotenv.env['STORAGE_BUCKET']}");
  
  // Set system UI overlay style for edge-to-edge
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );

  runApp(const BootstrapApp());
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // ========== CRITICAL: Must complete before app starts ==========
      // Only Firebase is truly required to start
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Load theme preference (fast operation)
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('isDarkMode');
      if (isDark != null) {
        themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
      }

      // Mark as initialized - show the app immediately!
      setState(() => _isInitialized = true);

      // ========== NON-CRITICAL: Run in background after app is visible ==========
      // These don't block the UI - they run in parallel
      _initializeBackgroundServices();
      
    } catch (e, stack) {
      print('Failed to initialize: $e\n$stack');
      setState(() {
        _errorMessage = 'Failed to initialize app: $e';
      });
    }
  }

  /// Initialize non-critical services in background without blocking UI
  void _initializeBackgroundServices() {
    // Run all these in parallel - don't await any of them
    Future.wait([
      _initCamera(),
      _initNotifications(),
      _initPermissions(),
      _initAppCheck(),
      _initPayment(),
    ]).then((_) {
      print('✅ All background services initialized');
    }).catchError((e) {
      print('⚠️ Some background services failed: $e');
    });
  }

  Future<void> _initCamera() async {
    try {
      cameras = await availableCameras().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('Camera init timeout');
          return [];
        },
      );
      print('✅ Camera initialized: ${cameras.length} cameras found');
    } catch (e) {
      print('⚠️ Camera init failed: $e');
    }
  }

  Future<void> _initNotifications() async {
    try {
      await LocalNotificationService().init();
      await LocalNotificationService().scheduleDailyNotification();
      print('✅ Notifications initialized');
    } catch (e) {
      print('⚠️ Notification init failed: $e');
    }
  }

  Future<void> _initPermissions() async {
    try {
      await PermissionService().requestInitialPermissions();
      print('✅ Permissions initialized');
    } catch (e) {
      print('⚠️ Permission request failed: $e');
    }
  }

  Future<void> _initAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
      print('✅ App Check initialized');
    } catch (e) {
      print('⚠️ App Check activation failed: $e');
    }
  }

  Future<void> _initPayment() async {
    try {
      // Don't await - let it run completely in background
      PaymentService().initialize();
      print('✅ Payment service initialization started');
    } catch (e) {
      print('⚠️ Payment service init failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Initialization Error',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _initializeApp,
                    child: const Text('Retry'),
                  )
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(color: Colors.deepOrange),
                SizedBox(height: 20),
                Text(
                  'Loading...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const MyApp();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Digital Diary',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            scaffoldBackgroundColor: Colors.black,
            canvasColor: Colors.black,
            cardColor: const Color(0xFF1A1A1A),
            dialogBackgroundColor: const Color(0xFF1A1A1A),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              elevation: 0,
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Colors.black,
            ),
            colorScheme: const ColorScheme.dark(
              surface: Colors.black,
              primary: Colors.blue,
            ),
          ),
          themeMode: currentMode,
          // The home property determines the first screen shown.
          // We use a StreamBuilder to listen to authentication changes.
          home: StreamBuilder(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (ctx, userSnapshot) {
              // If the connection is still waiting, show a loading spinner.
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              // If the snapshot has user data, it means the user is logged in.
              if (userSnapshot.hasData) {
                // Show the HomeScreen.
                return const HomeScreen();
              }
              // If there is no user data, show the LoginScreen.
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}

