// Manual script to create admin user in Firestore
//
// IMPORTANT: First create the admin user in Firebase Console Authentication:
// Email: admin1@elearning.com
// Password: Admin@123
//
// Then run this script to create the Firestore document manually

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const AdminSetupApp());
}

class AdminSetupApp extends StatelessWidget {
  const AdminSetupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Setup',
      home: const AdminSetupScreen(),
    );
  }
}

class AdminSetupScreen extends StatefulWidget {
  const AdminSetupScreen({super.key});

  @override
  State<AdminSetupScreen> createState() => _AdminSetupScreenState();
}

class _AdminSetupScreenState extends State<AdminSetupScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _emailController = TextEditingController(text: 'admin1@elearning.com');
  final _passwordController = TextEditingController(text: 'Admin@123');

  String _status = '';
  bool _isLoading = false;

  Future<void> _createAdminDocument() async {
    setState(() {
      _isLoading = true;
      _status = 'Creating admin document...';
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Sign in with the admin credentials
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;

      // Create user document in Firestore with admin role
      await _firestore.collection('users').doc(user.uid).set({
        'email': email,
        'name': 'Admin User',
        'photoUrl': null,
        'isPremium': false,
        'role': 'admin',
        'isBlocked': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'maxConcurrentSessions': 2,
      });

      setState(() {
        _status = '✅ SUCCESS! Admin document created for $email\n'
            'UID: ${user.uid}\n\n'
            'You can now login with:\n'
            'Email: $email\n'
            'Password: $password';
      });

      // Sign out
      await _auth.signOut();
    } catch (e) {
      setState(() {
        _status = '❌ ERROR: $e\n\n'
            'Make sure you created the user in Firebase Console first:\n'
            '1. Go to Firebase Console → Authentication → Users\n'
            '2. Click "Add User"\n'
            '3. Email: ${_emailController.text}\n'
            '4. Password: ${_passwordController.text}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Setup Helper')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Step 1: Create admin user in Firebase Console',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Go to Firebase Console → Authentication → Users → Add User',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Admin Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Admin Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Step 2: Create Firestore document',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _createAdminDocument,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Create Admin Firestore Document'),
            ),
            const SizedBox(height: 24),
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _status.startsWith('✅')
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _status,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
