import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
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

  // Initialize test course data and payment settings
  final initService = InitService();
  await initService.initializeTestData();

  runApp(const MyApp());
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
        home: const AuthWrapper(),
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
          return const MainAppScreen();
        }

        return const GoogleSignInScreen();
      },
    );
  }
}
