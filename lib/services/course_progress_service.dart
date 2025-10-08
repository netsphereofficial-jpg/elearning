import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/watch_session_model.dart';

class CourseProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get watch session for a specific video
  Future<WatchSessionModel?> getVideoWatchSession(
    String userId,
    String videoId,
  ) async {
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

  /// Get all completed video IDs for a specific course
  Future<List<String>> getCompletedVideoIds(
    String userId,
    String courseId,
  ) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('courseProgress')
          .doc(courseId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return List<String>.from(data['completedVideoIds'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting completed videos: $e');
      return [];
    }
  }

  /// Check if a video is unlocked (previous videos completed or is first/free)
  Future<bool> isVideoUnlocked({
    required String userId,
    required String courseId,
    required String videoId,
    required int videoOrder,
    required bool isFree,
    required List<String> allVideoIds,
  }) async {
    try {
      // Free preview videos are always unlocked
      if (isFree) return true;

      // First video is always unlocked
      if (videoOrder == 1) return true;

      // Get completed video IDs for this course
      final completedIds = await getCompletedVideoIds(userId, courseId);

      // Check if all previous videos are completed
      for (int i = 0; i < allVideoIds.length; i++) {
        final vid = allVideoIds[i];

        // If we've reached the current video, check if previous videos are done
        if (vid == videoId) {
          // Check all videos before this one
          for (int j = 0; j < i; j++) {
            if (!completedIds.contains(allVideoIds[j])) {
              return false; // Previous video not completed
            }
          }
          return true; // All previous videos completed
        }
      }

      return false;
    } catch (e) {
      print('Error checking video unlock status: $e');
      return false;
    }
  }

  /// Update watch progress for a video (real-time tracking)
  Future<void> updateVideoProgress({
    required String userId,
    required String videoId,
    required int currentPosition,
    required int maxWatchedPosition,
    required int totalWatchTime,
    required String deviceId,
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
        'maxWatchedPosition': maxWatchedPosition,
        'lastWatchedAt': FieldValue.serverTimestamp(),
        'totalWatchTime': totalWatchTime,
        'deviceId': deviceId,
        'isCompleted': false,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating video progress: $e');
    }
  }

  /// Mark video as completed and unlock next video in course
  Future<void> markVideoCompleted({
    required String userId,
    required String courseId,
    required String videoId,
    required int videoDuration,
  }) async {
    try {
      // Update watch history to mark completed
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('watchHistory')
          .doc(videoId)
          .update({
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
        'lastWatchedPosition': videoDuration,
        'maxWatchedPosition': videoDuration,
      });

      // Add to course progress completed list
      final progressRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('courseProgress')
          .doc(courseId);

      await progressRef.set({
        'completedVideoIds': FieldValue.arrayUnion([videoId]),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Video $videoId marked as completed for user $userId in course $courseId');
    } catch (e) {
      print('Error marking video completed: $e');
    }
  }

  /// Get course completion percentage
  Future<double> getCourseCompletionPercentage({
    required String userId,
    required String courseId,
    required int totalVideos,
  }) async {
    try {
      final completedIds = await getCompletedVideoIds(userId, courseId);
      if (totalVideos == 0) return 0.0;
      return (completedIds.length / totalVideos).clamp(0.0, 1.0);
    } catch (e) {
      print('Error calculating completion percentage: $e');
      return 0.0;
    }
  }

  /// Get watch sessions for all videos in a course
  Future<Map<String, WatchSessionModel>> getCourseWatchSessions({
    required String userId,
    required List<String> videoIds,
  }) async {
    try {
      Map<String, WatchSessionModel> sessions = {};

      for (String videoId in videoIds) {
        final session = await getVideoWatchSession(userId, videoId);
        if (session != null) {
          sessions[videoId] = session;
        }
      }

      return sessions;
    } catch (e) {
      print('Error getting course watch sessions: $e');
      return {};
    }
  }

  /// Check if user can access next video
  Future<bool> canAccessNextVideo({
    required String userId,
    required String courseId,
    required String currentVideoId,
    required List<String> allVideoIds,
  }) async {
    try {
      // Find current video index
      final currentIndex = allVideoIds.indexOf(currentVideoId);
      if (currentIndex == -1 || currentIndex == allVideoIds.length - 1) {
        return false; // Invalid or last video
      }

      // Check if current video is completed
      final session = await getVideoWatchSession(userId, currentVideoId);
      return session?.isCompleted ?? false;
    } catch (e) {
      print('Error checking next video access: $e');
      return false;
    }
  }
}
