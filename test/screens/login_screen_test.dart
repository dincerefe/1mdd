import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for LoginScreen validation logic and UI behavior
/// Since LoginScreen depends on Firebase, we test the form validation logic separately

void main() {
  group('Login Form Validation', () {
    group('Email Validation', () {
      test('empty email returns error', () {
        final result = validateEmail('');
        expect(result, 'Please enter your email');
      });

      test('email without @ returns error', () {
        final result = validateEmail('invalidemail');
        expect(result, 'Please enter a valid email');
      });

      test('email without domain returns error', () {
        final result = validateEmail('test@');
        expect(result, 'Please enter a valid email');
      });

      test('valid email returns null', () {
        final result = validateEmail('test@example.com');
        expect(result, isNull);
      });

      test('email with subdomain is valid', () {
        final result = validateEmail('test@mail.example.com');
        expect(result, isNull);
      });

      test('email with + sign is valid', () {
        final result = validateEmail('test+tag@example.com');
        expect(result, isNull);
      });
    });

    group('Password Validation', () {
      test('empty password returns error', () {
        final result = validatePassword('');
        expect(result, 'Please enter your password');
      });

      test('password less than 6 chars returns error', () {
        final result = validatePassword('12345');
        expect(result, 'Password must be at least 6 characters');
      });

      test('password with exactly 6 chars is valid', () {
        final result = validatePassword('123456');
        expect(result, isNull);
      });

      test('long password is valid', () {
        final result = validatePassword('mySecurePassword123!');
        expect(result, isNull);
      });
    });

    group('Username Validation (for signup)', () {
      test('empty username returns error', () {
        final result = validateUsername('');
        expect(result, 'Please enter a username');
      });

      test('username less than 3 chars returns error', () {
        final result = validateUsername('ab');
        expect(result, 'Username must be at least 3 characters');
      });

      test('username with exactly 3 chars is valid', () {
        final result = validateUsername('abc');
        expect(result, isNull);
      });

      test('username with spaces is valid', () {
        final result = validateUsername('John Doe');
        expect(result, isNull);
      });
    });
  });

  group('Terms Agreement Logic', () {
    test('cannot signup without agreeing to terms', () {
      final canProceed = canSubmitSignup(
        isLogin: false,
        isFormValid: true,
        agreedToTerms: false,
      );
      expect(canProceed, false);
    });

    test('can signup when agreed to terms', () {
      final canProceed = canSubmitSignup(
        isLogin: false,
        isFormValid: true,
        agreedToTerms: true,
      );
      expect(canProceed, true);
    });

    test('login does not require terms agreement', () {
      final canProceed = canSubmitSignup(
        isLogin: true,
        isFormValid: true,
        agreedToTerms: false,
      );
      expect(canProceed, true);
    });

    test('cannot proceed with invalid form', () {
      final canProceed = canSubmitSignup(
        isLogin: false,
        isFormValid: false,
        agreedToTerms: true,
      );
      expect(canProceed, false);
    });
  });

  group('LoginScreen Widget Tests', () {
    testWidgets('renders login form by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MockLoginForm(isLogin: true),
          ),
        ),
      );

      expect(find.text('Login'), findsWidgets);
      expect(find.byType(TextFormField), findsNWidgets(2)); // email + password
    });

    testWidgets('renders signup form with username field', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MockLoginForm(isLogin: false),
          ),
        ),
      );

      expect(find.text('Sign Up'), findsWidgets);
      expect(find.byType(TextFormField), findsNWidgets(3)); // username + email + password
    });

    testWidgets('toggles between login and signup', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MockLoginForm(isLogin: true),
          ),
        ),
      );

      // Initially login
      expect(find.text('Login'), findsWidgets);

      // Tap switch button
      await tester.tap(find.text('Switch to Sign Up'));
      await tester.pump();

      // Should show signup
      expect(find.text('Sign Up'), findsWidgets);
    });

    testWidgets('shows terms checkbox only in signup mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MockLoginForm(isLogin: false),
          ),
        ),
      );

      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('hides terms checkbox in login mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MockLoginForm(isLogin: true),
          ),
        ),
      );

      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('password visibility can be toggled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MockLoginForm(isLogin: true),
          ),
        ),
      );

      // Initially password is obscured
      expect(find.byIcon(Icons.visibility), findsOneWidget);

      // Tap visibility toggle
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      // Should show visibility_off icon
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('shows loading indicator during submission', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MockLoginForm(isLogin: true, isLoading: true),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('submit button is disabled during loading', (tester) async {
      // When isLoading is true, MockLoginForm shows CircularProgressIndicator
      // instead of the ElevatedButton - this is the expected behavior
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MockLoginForm(isLogin: true, isLoading: true),
          ),
        ),
      );

      // During loading, there should be NO ElevatedButton visible
      // (it's replaced by CircularProgressIndicator)
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('Error Handling', () {
    test('Firebase auth error messages are user-friendly', () {
      expect(
        getFirebaseErrorMessage('user-not-found'),
        'No user found with this email',
      );
      expect(
        getFirebaseErrorMessage('wrong-password'),
        'Wrong password provided',
      );
      expect(
        getFirebaseErrorMessage('email-already-in-use'),
        'An account already exists with this email',
      );
      expect(
        getFirebaseErrorMessage('weak-password'),
        'The password is too weak',
      );
      expect(
        getFirebaseErrorMessage('invalid-email'),
        'The email address is not valid',
      );
      expect(
        getFirebaseErrorMessage('unknown-error'),
        'An error occurred. Please try again.',
      );
    });
  });
}

// Validation functions (extracted from LoginScreen logic)
String? validateEmail(String value) {
  if (value.isEmpty) {
    return 'Please enter your email';
  }
  if (!value.contains('@') || !value.contains('.')) {
    return 'Please enter a valid email';
  }
  return null;
}

String? validatePassword(String value) {
  if (value.isEmpty) {
    return 'Please enter your password';
  }
  if (value.length < 6) {
    return 'Password must be at least 6 characters';
  }
  return null;
}

String? validateUsername(String value) {
  if (value.isEmpty) {
    return 'Please enter a username';
  }
  if (value.length < 3) {
    return 'Username must be at least 3 characters';
  }
  return null;
}

bool canSubmitSignup({
  required bool isLogin,
  required bool isFormValid,
  required bool agreedToTerms,
}) {
  if (!isFormValid) return false;
  if (!isLogin && !agreedToTerms) return false;
  return true;
}

String getFirebaseErrorMessage(String code) {
  switch (code) {
    case 'user-not-found':
      return 'No user found with this email';
    case 'wrong-password':
      return 'Wrong password provided';
    case 'email-already-in-use':
      return 'An account already exists with this email';
    case 'weak-password':
      return 'The password is too weak';
    case 'invalid-email':
      return 'The email address is not valid';
    default:
      return 'An error occurred. Please try again.';
  }
}

/// Mock login form widget for testing without Firebase
class MockLoginForm extends StatefulWidget {
  final bool isLogin;
  final bool isLoading;

  const MockLoginForm({
    super.key,
    required this.isLogin,
    this.isLoading = false,
  });

  @override
  State<MockLoginForm> createState() => _MockLoginFormState();
}

class _MockLoginFormState extends State<MockLoginForm> {
  late bool _isLogin;
  bool _obscurePassword = true;
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(_isLogin ? 'Login' : 'Sign Up',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          if (!_isLogin)
            TextFormField(
              decoration: const InputDecoration(labelText: 'Username'),
            ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          TextFormField(
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
          if (!_isLogin)
            Row(
              children: [
                Checkbox(
                  value: _agreedToTerms,
                  onChanged: (value) {
                    setState(() {
                      _agreedToTerms = value ?? false;
                    });
                  },
                ),
                const Text('I agree to Terms'),
              ],
            ),
          const SizedBox(height: 16),
          widget.isLoading
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: widget.isLoading ? null : () {},
                  child: Text(_isLogin ? 'Login' : 'Sign Up'),
                ),
          TextButton(
            onPressed: () {
              setState(() {
                _isLogin = !_isLogin;
              });
            },
            child: Text(_isLogin ? 'Switch to Sign Up' : 'Switch to Login'),
          ),
        ],
      ),
    );
  }
}
