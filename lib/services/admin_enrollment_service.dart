import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/enrollment_model.dart';
import '../models/course_model.dart';
import '../models/user_model.dart';

class AdminEnrollmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user by email
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return UserModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      print('Error getting user by email: $e');
      return null;
    }
  }

  // Check if user is already enrolled in a course
  Future<bool> isUserEnrolled(String userId, String courseId) async {
    try {
      final snapshot = await _firestore
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('courseId', isEqualTo: courseId)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking enrollment: $e');
      return false;
    }
  }

  // Manually enroll user in course
  Future<bool> manuallyEnrollUser({
    required String userId,
    required String userEmail,
    required String courseId,
    required String courseTitle,
    required int validityDays,
    required String adminId,
  }) async {
    try {
      // Check if already enrolled
      final alreadyEnrolled = await isUserEnrolled(userId, courseId);
      if (alreadyEnrolled) {
        print('User already enrolled in this course');
        return false;
      }

      // Calculate validity date
      final validUntil = DateTime.now().add(Duration(days: validityDays));

      // Create enrollment
      final enrollment = EnrollmentModel(
        id: '',
        userId: userId,
        userEmail: userEmail,
        courseId: courseId,
        courseTitle: courseTitle,
        transactionId: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
        amount: 0, // Manual enrollment is free
        enrolledAt: DateTime.now(),
        status: 'approved', // Auto-approve manual enrollments
        validUntil: validUntil,
        approvedBy: adminId,
        approvedAt: DateTime.now(),
      );

      await _firestore.collection('enrollments').add(enrollment.toFirestore());
      print('User manually enrolled: $userId in $courseId');
      return true;
    } catch (e) {
      print('Error manually enrolling user: $e');
      return false;
    }
  }

  // Manually enroll user in multiple courses
  Future<Map<String, bool>> manuallyEnrollUserInCourses({
    required String userId,
    required String userEmail,
    required List<String> courseIds,
    required Map<String, String> courseTitles,
    required Map<String, int> courseValidityDays,
    required String adminId,
  }) async {
    Map<String, bool> results = {};

    for (String courseId in courseIds) {
      final success = await manuallyEnrollUser(
        userId: userId,
        userEmail: userEmail,
        courseId: courseId,
        courseTitle: courseTitles[courseId] ?? 'Unknown Course',
        validityDays: courseValidityDays[courseId] ?? 30,
        adminId: adminId,
      );
      results[courseId] = success;
    }

    return results;
  }

  // Get all enrollments (for admin view)
  Future<List<EnrollmentModel>> getAllEnrollments({String? status}) async {
    try {
      Query query = _firestore.collection('enrollments');

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.orderBy('enrolledAt', descending: true).get();
      return snapshot.docs.map((doc) => EnrollmentModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting all enrollments: $e');
      return [];
    }
  }

  // Revoke user enrollment
  Future<bool> revokeEnrollment(String enrollmentId, String reason) async {
    try {
      await _firestore.collection('enrollments').doc(enrollmentId).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'revokedAt': FieldValue.serverTimestamp(),
      });

      print('Enrollment revoked: $enrollmentId');
      return true;
    } catch (e) {
      print('Error revoking enrollment: $e');
      return false;
    }
  }

  // Extend enrollment validity
  Future<bool> extendEnrollmentValidity(String enrollmentId, int additionalDays) async {
    try {
      final doc = await _firestore.collection('enrollments').doc(enrollmentId).get();
      if (!doc.exists) {
        return false;
      }

      final enrollment = EnrollmentModel.fromFirestore(doc);
      final currentValidUntil = enrollment.validUntil ?? DateTime.now();
      final newValidUntil = currentValidUntil.add(Duration(days: additionalDays));

      await _firestore.collection('enrollments').doc(enrollmentId).update({
        'validUntil': Timestamp.fromDate(newValidUntil),
        'extendedAt': FieldValue.serverTimestamp(),
      });

      print('Enrollment validity extended: $enrollmentId');
      return true;
    } catch (e) {
      print('Error extending enrollment validity: $e');
      return false;
    }
  }

  // Get user's enrolled courses
  Future<List<String>> getUserEnrolledCourseIds(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['courseId'] as String)
          .toList();
    } catch (e) {
      print('Error getting user enrolled courses: $e');
      return [];
    }
  }

  // Get enrollment statistics including live and expired students
  Future<Map<String, dynamic>> getEnrollmentStats() async {
    try {
      final snapshot = await _firestore
          .collection('enrollments')
          .where('status', isEqualTo: 'approved')
          .get();

      int totalEnrollments = 0;
      int liveStudents = 0;
      int expiredStudents = 0;
      int expiringSoon = 0; // Expiring within 7 days
      Set<String> uniqueStudentIds = {};

      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        final enrollment = EnrollmentModel.fromFirestore(doc);
        totalEnrollments++;
        uniqueStudentIds.add(enrollment.userId);

        // Check if enrollment is valid (live)
        if (enrollment.isValid) {
          liveStudents++;

          // Check if expiring within 7 days
          if (enrollment.validUntil != null) {
            final daysUntilExpiry = enrollment.validUntil!.difference(now).inDays;
            if (daysUntilExpiry > 0 && daysUntilExpiry <= 7) {
              expiringSoon++;
            }
          }
        } else {
          expiredStudents++;
        }
      }

      return {
        'totalEnrollments': totalEnrollments,
        'uniqueStudents': uniqueStudentIds.length,
        'liveStudents': liveStudents,
        'expiredStudents': expiredStudents,
        'expiringSoon': expiringSoon,
      };
    } catch (e) {
      print('Error getting enrollment stats: $e');
      return {
        'totalEnrollments': 0,
        'uniqueStudents': 0,
        'liveStudents': 0,
        'expiredStudents': 0,
        'expiringSoon': 0,
      };
    }
  }

  // Update enrollment validity date
  Future<bool> updateEnrollmentValidity(String enrollmentId, DateTime newValidUntil) async {
    try {
      await _firestore.collection('enrollments').doc(enrollmentId).update({
        'validUntil': Timestamp.fromDate(newValidUntil),
        'validityUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('Enrollment validity updated: $enrollmentId');
      return true;
    } catch (e) {
      print('Error updating enrollment validity: $e');
      return false;
    }
  }

  // Get enrollments by validity status
  Future<List<EnrollmentModel>> getEnrollmentsByStatus({
    required bool isLive, // true for live, false for expired
  }) async {
    try {
      final snapshot = await _firestore
          .collection('enrollments')
          .where('status', isEqualTo: 'approved')
          .orderBy('validUntil', descending: true)
          .get();

      final now = DateTime.now();
      final enrollments = snapshot.docs
          .map((doc) => EnrollmentModel.fromFirestore(doc))
          .where((enrollment) {
            if (isLive) {
              return enrollment.isValid;
            } else {
              return !enrollment.isValid;
            }
          })
          .toList();

      return enrollments;
    } catch (e) {
      print('Error getting enrollments by status: $e');
      return [];
    }
  }
}
