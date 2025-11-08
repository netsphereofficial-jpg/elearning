import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/enrollment_model.dart';
import '../models/course_model.dart';

class AdminPaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get pending payments
  Future<List<EnrollmentModel>> getPendingPayments() async {
    try {
      final snapshot = await _firestore
          .collection('enrollments')
          .where('status', isEqualTo: 'pending')
          .orderBy('enrolledAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => EnrollmentModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting pending payments: $e');
      return [];
    }
  }

  // Get approved payments
  Future<List<EnrollmentModel>> getApprovedPayments() async {
    try {
      final snapshot = await _firestore
          .collection('enrollments')
          .where('status', isEqualTo: 'approved')
          .orderBy('approvedAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs.map((doc) => EnrollmentModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting approved payments: $e');
      return [];
    }
  }

  // Get rejected payments
  Future<List<EnrollmentModel>> getRejectedPayments() async {
    try {
      final snapshot = await _firestore
          .collection('enrollments')
          .where('status', isEqualTo: 'rejected')
          .orderBy('enrolledAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs.map((doc) => EnrollmentModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting rejected payments: $e');
      return [];
    }
  }

  // Approve payment
  Future<bool> approvePayment(String enrollmentId, String adminId) async {
    try {
      // Get enrollment
      final enrollmentDoc = await _firestore.collection('enrollments').doc(enrollmentId).get();
      if (!enrollmentDoc.exists) {
        throw Exception('Enrollment not found');
      }

      final enrollment = EnrollmentModel.fromFirestore(enrollmentDoc);

      // Get course to calculate validUntil
      final courseDoc = await _firestore.collection('courses').doc(enrollment.courseId).get();
      if (!courseDoc.exists) {
        throw Exception('Course not found');
      }

      final course = CourseModel.fromFirestore(courseDoc);

      // Calculate validity date
      final validUntil = DateTime.now().add(Duration(days: course.validityDays));

      // Update enrollment
      await _firestore.collection('enrollments').doc(enrollmentId).update({
        'status': 'approved',
        'approvedBy': adminId,
        'approvedAt': FieldValue.serverTimestamp(),
        'validUntil': Timestamp.fromDate(validUntil),
      });

      print('✅ Payment approved: $enrollmentId by admin: $adminId');
      return true;
    } on FirebaseException catch (e) {
      print('❌ Firestore Error approving payment: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied: You must be an admin to approve payments.');
      } else if (e.code == 'not-found') {
        throw Exception('Enrollment not found.');
      }
      throw Exception('Failed to approve payment: ${e.message ?? e.code}');
    } catch (e) {
      print('❌ Error approving payment: $e');
      rethrow;
    }
  }

  // Reject payment
  Future<bool> rejectPayment(String enrollmentId, String adminId, String reason) async {
    try {
      await _firestore.collection('enrollments').doc(enrollmentId).update({
        'status': 'rejected',
        'approvedBy': adminId,
        'approvedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
      });

      print('✅ Payment rejected: $enrollmentId by admin: $adminId');
      return true;
    } on FirebaseException catch (e) {
      print('❌ Firestore Error rejecting payment: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied: You must be an admin to reject payments.');
      } else if (e.code == 'not-found') {
        throw Exception('Enrollment not found.');
      }
      throw Exception('Failed to reject payment: ${e.message ?? e.code}');
    } catch (e) {
      print('❌ Error rejecting payment: $e');
      rethrow;
    }
  }

  // Get all payments (for history/reports)
  Future<List<EnrollmentModel>> getAllPayments({int limit = 100}) async {
    try {
      final snapshot = await _firestore
          .collection('enrollments')
          .orderBy('enrolledAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => EnrollmentModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting all payments: $e');
      return [];
    }
  }

  // Get payment statistics
  Future<Map<String, dynamic>> getPaymentStats() async {
    try {
      final allPayments = await _firestore.collection('enrollments').get();

      int pending = 0;
      int approved = 0;
      int rejected = 0;
      int totalRevenue = 0;

      for (var doc in allPayments.docs) {
        final data = doc.data();
        final status = data['status'] ?? '';
        final amount = data['amount'] ?? 0;

        switch (status) {
          case 'pending':
            pending++;
            break;
          case 'approved':
            approved++;
            totalRevenue += amount as int;
            break;
          case 'rejected':
            rejected++;
            break;
        }
      }

      return {
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
        'total': allPayments.docs.length,
        'totalRevenue': totalRevenue,
      };
    } catch (e) {
      print('Error getting payment stats: $e');
      return {
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'total': 0,
        'totalRevenue': 0,
      };
    }
  }

  // Search payments by transaction ID or user email
  Future<List<EnrollmentModel>> searchPayments(String query) async {
    try {
      // Try to search by transaction ID
      final byTransactionId = await _firestore
          .collection('enrollments')
          .where('transactionId', isEqualTo: query)
          .get();

      if (byTransactionId.docs.isNotEmpty) {
        return byTransactionId.docs.map((doc) => EnrollmentModel.fromFirestore(doc)).toList();
      }

      // Try to search by user email
      final byEmail = await _firestore
          .collection('enrollments')
          .where('userEmail', isEqualTo: query.toLowerCase())
          .get();

      return byEmail.docs.map((doc) => EnrollmentModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error searching payments: $e');
      return [];
    }
  }
}
