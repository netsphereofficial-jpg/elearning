import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'dart:html' as html;
import 'firebase_options.dart';
import 'constants/app_theme.dart';
import 'services/google_auth_service.dart';
import 'services/init_service.dart';
import 'screens/google_signin_screen.dart';
import 'screens/main_app_screen.dart';
import 'screens/admin/admin_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
//XLDynamics
  // Initialize test course data and payment settings
  final initService = InitService();
  await initService.initializeTestData();

  // Disable right-click globally for the entire app (web only)
  _disableRightClickGlobally();

  runApp(const MyApp());
}

/// Disable right-click context menu globally across the entire app
void _disableRightClickGlobally() {
  try {
    // Disable right-click on document body
    html.document.body?.addEventListener('contextmenu', (event) {
      event.preventDefault();
      event.stopPropagation();
      print('🚫 Right-click disabled globally');
      return false;
    });

    // Disable right-click on entire document
    html.document.addEventListener('contextmenu', (event) {
      event.preventDefault();
      event.stopPropagation();
      return false;
    });

    // Disable text selection and copy (optional - makes it harder to copy content)
    html.document.body?.style.userSelect = 'none';
    html.document.body?.style.setProperty('-webkit-user-select', 'none');

    // Disable keyboard shortcuts that can be used to download/inspect
    html.document.addEventListener('keydown', (event) {
      final keyboardEvent = event as html.KeyboardEvent;

      // Disable F12 (DevTools)
      if (keyboardEvent.keyCode == 123) {
        event.preventDefault();
        print('🚫 F12 (DevTools) blocked');
        return false;
      }

      // Disable Ctrl+Shift+I (Inspect)
      if (keyboardEvent.ctrlKey && keyboardEvent.shiftKey && keyboardEvent.keyCode == 73) {
        event.preventDefault();
        print('🚫 Ctrl+Shift+I blocked');
        return false;
      }

      // Disable Ctrl+Shift+C (Inspect Element)
      if (keyboardEvent.ctrlKey && keyboardEvent.shiftKey && keyboardEvent.keyCode == 67) {
        event.preventDefault();
        print('🚫 Ctrl+Shift+C blocked');
        return false;
      }

      // Disable Ctrl+U (View Source)
      if (keyboardEvent.ctrlKey && keyboardEvent.keyCode == 85) {
        event.preventDefault();
        print('🚫 Ctrl+U blocked');
        return false;
      }

      // Disable Ctrl+S (Save Page)
      if (keyboardEvent.ctrlKey && keyboardEvent.keyCode == 83) {
        event.preventDefault();
        print('🚫 Ctrl+S blocked');
        return false;
      }
    });

    print('✅ Global right-click protection enabled');
    print('✅ DevTools keyboard shortcuts blocked');
  } catch (e) {
    print('Error setting up global right-click protection: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<GoogleAuthService>(
          create: (_) => GoogleAuthService(),
        ),
      ],
      child: MaterialApp(
        title: 'E-Learning Platform',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthWrapper(),
          '/admin': (context) => const AdminLoginScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<GoogleAuthService>();

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // Check if the logged-in user is an admin
          return FutureBuilder(
            future: authService.getUserData(snapshot.data!.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              // If user is admin, sign them out from regular user flow
              if (userSnapshot.hasData && userSnapshot.data!.isAdmin) {
                return const GoogleSignInScreen();
              }

              return const MainAppScreen();
            },
          );
        }

        return const GoogleSignInScreen();
      },
    );
  }
}
