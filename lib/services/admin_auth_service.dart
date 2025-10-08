import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AdminAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password (admin only)
  Future<UserModel?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential result;

      // Try to sign in
      try {
        result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        // If user doesn't exist and it's an admin email, create it
        if ((e.code == 'user-not-found' || e.code == 'invalid-credential') &&
            _isAdminEmail(email)) {
          print('Admin user not found. Creating admin account...');
          result = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

          // Create Firestore document immediately for new admin
          await _createAdminFirestoreDocument(result.user!, email);
        } else {
          rethrow;
        }
      }

      final User? user = result.user;
      if (user == null) {
        throw Exception('Sign in failed');
      }

      // Check if user is admin
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // If Firestore doc doesn't exist but it's an admin email, create it
        if (_isAdminEmail(email)) {
          await _createAdminFirestoreDocument(user, email);
          return await _firestore.collection('users').doc(user.uid).get().then(
            (doc) => UserModel.fromFirestore(doc)
          );
        }
        await _auth.signOut();
        throw Exception('User not found');
      }

      final userData = UserModel.fromFirestore(userDoc);

      // Verify admin role
      if (!userData.isAdmin) {
        await _auth.signOut();
        throw Exception('Access denied. Admin privileges required.');
      }

      // Check if account is blocked
      if (userData.isBlocked) {
        await _auth.signOut();
        throw Exception('Account is blocked. Contact support.');
      }

      // Update last login
      await _firestore.collection('users').doc(user.uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      print('Admin signed in: ${userData.email}');
      return userData;
    } on FirebaseAuthException catch (e) {
      print('Admin sign in error: ${e.code}');
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No admin account found with this email.');
        case 'wrong-password':
          throw Exception('Incorrect password.');
        case 'invalid-credential':
          throw Exception('Invalid email or password. Please check your credentials.');
        case 'invalid-email':
          throw Exception('Invalid email format.');
        case 'user-disabled':
          throw Exception('This account has been disabled.');
        case 'too-many-requests':
          throw Exception('Too many failed attempts. Try again later.');
        default:
          throw Exception('Sign in failed: ${e.message}');
      }
    } catch (e) {
      print('Admin sign in error: $e');
      rethrow;
    }
  }

  // Get current admin user data
  Future<UserModel?> getCurrentAdminUser() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;

      final userData = UserModel.fromFirestore(userDoc);

      // Verify still admin and not blocked
      if (!userData.isAdmin || userData.isBlocked) {
        await signOut();
        return null;
      }

      return userData;
    } catch (e) {
      print('Error getting current admin user: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('Admin signed out');
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    try {
      final adminUser = await getCurrentAdminUser();
      return adminUser != null && adminUser.isAdmin;
    } catch (e) {
      return false;
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      print('Password reset error: ${e.code}');
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No account found with this email.');
        case 'invalid-email':
          throw Exception('Invalid email format.');
        default:
          throw Exception('Failed to send reset email: ${e.message}');
      }
    } catch (e) {
      print('Password reset error: $e');
      rethrow;
    }
  }

  // Check if email is an admin email
  bool _isAdminEmail(String email) {
    final adminEmails = [
      'admin1@elearning.com',
      'admin2@elearning.com',
      'admin3@elearning.com',
    ];
    return adminEmails.contains(email.toLowerCase());
  }

  // Create admin Firestore document
  Future<void> _createAdminFirestoreDocument(User user, String email) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'email': email,
        'name': email.split('@')[0].replaceAll('admin', 'Admin '),
        'photoUrl': null,
        'isPremium': false,
        'role': 'admin',
        'isBlocked': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'maxConcurrentSessions': 2,
      });
      print('✅ Created admin Firestore document for $email');
    } catch (e) {
      print('Error creating admin Firestore document: $e');
      rethrow;
    }
  }
}
