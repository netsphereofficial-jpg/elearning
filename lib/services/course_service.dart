import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_model.dart';
import '../models/enrollment_model.dart';

class CourseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all published courses
  Future<List<CourseModel>> getAllCourses() async {
    try {
      final snapshot = await _firestore
          .collection('courses')
          .where('isPublished', isEqualTo: true)
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs.map((doc) => CourseModel.fromFirestore(doc)).toList();
    } on FirebaseException catch (e) {
      print('❌ Firestore Error getting courses: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied: Unable to access courses. Please check Firestore security rules.');
      }
      throw Exception('Failed to load courses: ${e.message ?? e.code}');
    } catch (e) {
      print('❌ Error getting courses: $e');
      throw Exception('Unexpected error loading courses: $e');
    }
  }

  // Get course by ID
  Future<CourseModel?> getCourseById(String courseId) async {
    try {
      final doc = await _firestore.collection('courses').doc(courseId).get();
      if (doc.exists) {
        return CourseModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting course: $e');
      return null;
    }
  }

  // Check if user is enrolled in a course and enrollment is still valid
  Future<bool> isUserEnrolled(String userId, String courseId) async {
    try {
      final snapshot = await _firestore
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('courseId', isEqualTo: courseId)
          .where('status', isEqualTo: 'approved') // Changed from 'completed' to 'approved'
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return false;
      }

      // Check if enrollment is still valid (not expired)
      final enrollment = EnrollmentModel.fromFirestore(snapshot.docs.first);
      return enrollment.isValid; // Uses the isValid getter which checks expiry
    } catch (e) {
      print('Error checking enrollment: $e');
      return false;
    }
  }

  // Check enrollment status (approved, pending, rejected, expired)
  Future<String> checkEnrollmentStatus(String userId, String courseId) async {
    try {
      final snapshot = await _firestore
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('courseId', isEqualTo: courseId)
          .orderBy('enrolledAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return 'not_enrolled';
      }

      final enrollment = EnrollmentModel.fromFirestore(snapshot.docs.first);

      if (enrollment.status == 'pending') {
        return 'pending';
      }

      if (enrollment.status == 'rejected') {
        return 'rejected';
      }

      if (enrollment.status == 'approved') {
        if (enrollment.isValid) {
          return 'active';
        } else {
          return 'expired';
        }
      }

      return 'not_enrolled';
    } catch (e) {
      print('Error checking enrollment status: $e');
      return 'error';
    }
  }

  // Enroll user in a course
  Future<bool> enrollUser(EnrollmentModel enrollment) async {
    try {
      await _firestore.collection('enrollments').add(enrollment.toFirestore());
      return true;
    } on FirebaseException catch (e) {
      print('❌ Firestore Error enrolling user: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied: Unable to submit enrollment. Please ensure you are logged in.');
      }
      throw Exception('Failed to submit enrollment: ${e.message ?? e.code}');
    } catch (e) {
      print('❌ Error enrolling user: $e');
      throw Exception('Unexpected error during enrollment: $e');
    }
  }

  // Get all enrollments for a user
  Future<List<EnrollmentModel>> getUserEnrollments(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved') // Changed from 'completed' to 'approved'
          .orderBy('enrolledAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => EnrollmentModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting user enrollments: $e');
      return [];
    }
  }

  // Get enrolled courses for a user
  Future<List<CourseModel>> getUserEnrolledCourses(String userId) async {
    try {
      final enrollments = await getUserEnrollments(userId);
      final courseIds = enrollments.map((e) => e.courseId).toList();

      if (courseIds.isEmpty) {
        return [];
      }

      final courses = <CourseModel>[];
      for (String courseId in courseIds) {
        final course = await getCourseById(courseId);
        if (course != null) {
          courses.add(course);
        }
      }

      return courses;
    } catch (e) {
      print('Error getting enrolled courses: $e');
      return [];
    }
  }

  // Get payment settings (QR code, UPI ID)
  Future<Map<String, dynamic>?> getPaymentSettings() async {
    try {
      final doc = await _firestore.collection('settings').doc('payment').get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting payment settings: $e');
      return null;
    }
  }
}
