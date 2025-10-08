import 'package:cloud_firestore/cloud_firestore.dart';

class InitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize app with test video if needed
  Future<void> initializeTestData() async {
    try {
      // Check if videos collection is empty
      final videosSnapshot = await _firestore.collection('videos').limit(1).get();

      if (videosSnapshot.docs.isEmpty) {
        print('Adding test video to Firestore...');

        // Add your test video
        await _firestore.collection('videos').add({
          'title': 'Test Video - Demo',
          'description': 'This is a test video from Bunny Stream',
          'bunnyVideoGuid': '62d26a71-7b57-43c7-bdf2-8da954fc45c8',
          'thumbnailUrl':
              'https://vz-d86440c8-58b.b-cdn.net/62d26a71-7b57-43c7-bdf2-8da954fc45c8/thumbnail.jpg',
          'durationInSeconds': 300,
          'category': 'Demo',
          'isPremium': false,
          'uploadedAt': FieldValue.serverTimestamp(),
          'viewCount': 0,
          'tags': ['demo', 'test'],
          'processingStatus': 'completed',
        });

        print('✅ Test video added successfully!');
      } else {
        print('Videos already exist in Firestore');
      }
    } catch (e) {
      print('Error initializing test data: $e');
    }
  }
}
