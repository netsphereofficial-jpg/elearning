import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current payment settings
  Future<Map<String, dynamic>> getPaymentSettings() async {
    try {
      final doc = await _firestore.collection('settings').doc('payment').get();

      if (!doc.exists) {
        // Return default settings if not found
        return {
          'qrCodeImageUrl': '',
          'upiId': '',
          'paymentNote': '',
        };
      }

      return doc.data() ?? {};
    } catch (e) {
      print('Error getting payment settings: $e');
      rethrow;
    }
  }

  /// Update payment settings
  Future<bool> updatePaymentSettings({
    required String qrCodeImageUrl,
    required String upiId,
    required String paymentNote,
  }) async {
    try {
      await _firestore.collection('settings').doc('payment').set({
        'qrCodeImageUrl': qrCodeImageUrl.trim(),
        'upiId': upiId.trim(),
        'paymentNote': paymentNote.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('Payment settings updated successfully');
      return true;
    } catch (e) {
      print('Error updating payment settings: $e');
      return false;
    }
  }
}
