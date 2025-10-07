import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Dummy login for testing (email/password)
  Future<UserModel?> dummyLogin(String email, String password) async {
    try {
      // For now, we'll accept any email/password combination
      // In production, you'd verify credentials properly

      // Try to sign in
      UserCredential userCredential;
      try {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (e) {
        // If user doesn't exist, create them
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Create user document in Firestore
        await _createUserDocument(userCredential.user!);
      }

      // Update last login
      await _updateLastLogin(userCredential.user!.uid);

      // Store session token
      final token = await userCredential.user!.getIdToken();
      await _storage.write(key: 'auth_token', value: token);

      // Get user data
      return await getUserData(userCredential.user!.uid);
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(User user) async {
    final userModel = UserModel(
      id: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? user.email?.split('@')[0] ?? 'User',
      photoUrl: user.photoURL,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(userModel.toFirestore());
  }

  // Update last login timestamp
  Future<void> _updateLastLogin(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Logout
  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _auth.signOut();
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null && currentUser != null;
  }

  // Get stored token
  Future<String?> getAuthToken() async {
    return await _storage.read(key: 'auth_token');
  }

  // Register device for session management
  Future<void> registerDeviceSession(String userId, String deviceId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .doc(deviceId)
        .set({
      'deviceId': deviceId,
      'lastActiveAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
  }

  // Check concurrent sessions
  Future<bool> checkConcurrentSessions(String userId, int maxSessions) async {
    final sessionsSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .where('isActive', isEqualTo: true)
        .get();

    return sessionsSnapshot.docs.length < maxSessions;
  }

  // Invalidate old sessions
  Future<void> invalidateOldSessions(String userId, String currentDeviceId) async {
    final sessions = await _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .where('isActive', isEqualTo: true)
        .get();

    for (var session in sessions.docs) {
      if (session.id != currentDeviceId) {
        await session.reference.update({'isActive': false});
      }
    }
  }
}
