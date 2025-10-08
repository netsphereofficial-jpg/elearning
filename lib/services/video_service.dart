import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/video_model.dart';
import '../models/watch_session_model.dart';

class VideoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Get all videos
  Future<List<VideoModel>> getAllVideos() async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .orderBy('uploadedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => VideoModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting videos: $e');
      return [];
    }
  }

  // Get videos by category
  Future<List<VideoModel>> getVideosByCategory(String category) async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('category', isEqualTo: category)
          .orderBy('uploadedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => VideoModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting videos by category: $e');
      return [];
    }
  }

  // Get video by ID
  Future<VideoModel?> getVideoById(String videoId) async {
    try {
      final doc = await _firestore.collection('videos').doc(videoId).get();
      if (doc.exists) {
        return VideoModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting video: $e');
      return null;
    }
  }

  // Generate video URL directly from Bunny CDN (no Cloud Function needed)
  Future<String?> generateSignedVideoUrl(String userId, String videoId) async {
    try {
      // Get video document
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();

      if (!videoDoc.exists) {
        print('Video not found');
        return null;
      }

      final videoData = videoDoc.data();
      final bunnyVideoGuid = videoData?['bunnyVideoGuid'];

      if (bunnyVideoGuid == null) {
        print('Video GUID not found');
        return null;
      }

      // Direct Bunny Stream HLS URL
      final videoUrl = 'https://vz-d86440c8-58b.b-cdn.net/$bunnyVideoGuid/playlist.m3u8';

      print('Generated video URL: $videoUrl');
      return videoUrl;
    } catch (e) {
      print('Error generating video URL: $e');
      return null;
    }
  }

  // Get watch session for user and video
  Future<WatchSessionModel?> getWatchSession(String userId, String videoId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('watchHistory')
          .doc(videoId)
          .get();

      if (doc.exists) {
        return WatchSessionModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting watch session: $e');
      return null;
    }
  }

  // Update watch progress
  Future<void> updateWatchProgress({
    required String userId,
    required String videoId,
    required int currentPosition,
    required int totalWatchTime,
    required String deviceId,
    String? ipAddress,
  }) async {
    try {
      final sessionRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('watchHistory')
          .doc(videoId);

      await sessionRef.set({
        'userId': userId,
        'videoId': videoId,
        'lastWatchedPosition': currentPosition,
        'lastWatchedAt': FieldValue.serverTimestamp(),
        'totalWatchTime': totalWatchTime,
        'deviceId': deviceId,
        'ipAddress': ipAddress,
        'isCompleted': false,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating watch progress: $e');
    }
  }

  // Mark video as completed
  Future<void> markVideoCompleted(String userId, String videoId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('watchHistory')
          .doc(videoId)
          .update({
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Increment view count
      await _firestore.collection('videos').doc(videoId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error marking video completed: $e');
    }
  }

  // Get user's watch history
  Future<List<WatchSessionModel>> getUserWatchHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('watchHistory')
          .orderBy('lastWatchedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => WatchSessionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting watch history: $e');
      return [];
    }
  }

  // Check if user has access to video
  Future<bool> checkVideoAccess(String userId, String videoId) async {
    try {
      final video = await getVideoById(videoId);
      if (video == null) return false;

      // If video is free, grant access
      if (!video.isPremium) return true;

      // Check if user has premium subscription
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final isPremium = userDoc.data()?['isPremium'] ?? false;
        return isPremium;
      }

      return false;
    } catch (e) {
      print('Error checking video access: $e');
      return false;
    }
  }

  // Search videos
  Stream<List<VideoModel>> searchVideos(String query) {
    return _firestore
        .collection('videos')
        .orderBy('title')
        .startAt([query])
        .endAt([query + '\uf8ff'])
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => VideoModel.fromFirestore(doc)).toList());
  }
}
