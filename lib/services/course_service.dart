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
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => CourseModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting courses: $e');
      return [];
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

  // Check if user is enrolled in a course
  Future<bool> isUserEnrolled(String userId, String courseId) async {
    try {
      final snapshot = await _firestore
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('courseId', isEqualTo: courseId)
          .where('status', isEqualTo: 'completed')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking enrollment: $e');
      return false;
    }
  }

  // Enroll user in a course
  Future<bool> enrollUser(EnrollmentModel enrollment) async {
    try {
      await _firestore.collection('enrollments').add(enrollment.toFirestore());
      return true;
    } catch (e) {
      print('Error enrolling user: $e');
      return false;
    }
  }

  // Get all enrollments for a user
  Future<List<EnrollmentModel>> getUserEnrollments(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
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
