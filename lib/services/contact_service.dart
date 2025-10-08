import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contact_submission_model.dart';

class ContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Submit contact form
  Future<bool> submitContactForm(ContactSubmissionModel submission) async {
    try {
      await _firestore.collection('contactSubmissions').add(submission.toFirestore());
      return true;
    } catch (e) {
      print('Error submitting contact form: $e');
      return false;
    }
  }

  // Get all contact submissions (for admin - future use)
  Future<List<ContactSubmissionModel>> getAllSubmissions() async {
    try {
      final snapshot = await _firestore
          .collection('contactSubmissions')
          .orderBy('submittedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ContactSubmissionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting contact submissions: $e');
      return [];
    }
  }

  // Mark submission as read (for admin - future use)
  Future<bool> markAsRead(String submissionId) async {
    try {
      await _firestore
          .collection('contactSubmissions')
          .doc(submissionId)
          .update({'isRead': true});
      return true;
    } catch (e) {
      print('Error marking submission as read: $e');
      return false;
    }
  }
}
