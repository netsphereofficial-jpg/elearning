import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/enrollment_model.dart';

class AdminUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all users with pagination
  Future<List<UserModel>> getAllUsers({int limit = 100, DocumentSnapshot? startAfter}) async {
    try {
      Query query = _firestore.collection('users').orderBy('createdAt', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // Get user enrollments
  Future<List<EnrollmentModel>> getUserEnrollments(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .orderBy('enrolledAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => EnrollmentModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting user enrollments: $e');
      return [];
    }
  }

  // Block user
  Future<bool> blockUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isBlocked': true,
        'blockedAt': FieldValue.serverTimestamp(),
      });

      print('User blocked: $userId');
      return true;
    } catch (e) {
      print('Error blocking user: $e');
      return false;
    }
  }

  // Unblock user
  Future<bool> unblockUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isBlocked': false,
        'unblockedAt': FieldValue.serverTimestamp(),
      });

      print('User unblocked: $userId');
      return true;
    } catch (e) {
      print('Error unblocking user: $e');
      return false;
    }
  }

  // Delete user (soft delete by blocking)
  Future<bool> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isBlocked': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      print('User deleted: $userId');
      return true;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  // Update user role
  Future<bool> updateUserRole(String userId, UserRole role) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': role.toJson(),
        'roleUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('User role updated: $userId -> ${role.name}');
      return true;
    } catch (e) {
      print('Error updating user role: $e');
      return false;
    }
  }

  // Toggle premium status
  Future<bool> togglePremiumStatus(String userId, bool isPremium) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isPremium': isPremium,
        'premiumUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('User premium status updated: $userId -> $isPremium');
      return true;
    } catch (e) {
      print('Error updating premium status: $e');
      return false;
    }
  }

  // Search users by email or name
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final lowercaseQuery = query.toLowerCase();

      // Search by email
      final byEmail = await _firestore
          .collection('users')
          .where('email', isEqualTo: lowercaseQuery)
          .get();

      if (byEmail.docs.isNotEmpty) {
        return byEmail.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
      }

      // Search by name (partial match - get all and filter)
      final allUsers = await _firestore.collection('users').limit(100).get();

      return allUsers.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) => user.name.toLowerCase().contains(lowercaseQuery) ||
                          user.email.toLowerCase().contains(lowercaseQuery))
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Get user statistics
  Future<Map<String, int>> getUserStats() async {
    try {
      final snapshot = await _firestore.collection('users').get();

      int totalUsers = snapshot.docs.length;
      int admins = 0;
      int blocked = 0;
      int premium = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['role'] == 'admin') admins++;
        if (data['isBlocked'] == true) blocked++;
        if (data['isPremium'] == true) premium++;
      }

      return {
        'total': totalUsers,
        'admins': admins,
        'users': totalUsers - admins,
        'blocked': blocked,
        'premium': premium,
      };
    } catch (e) {
      print('Error getting user stats: $e');
      return {'total': 0, 'admins': 0, 'users': 0, 'blocked': 0, 'premium': 0};
    }
  }
}
