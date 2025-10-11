import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_model.dart';

class AdminCourseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all courses (including unpublished)
  Future<List<CourseModel>> getAllCourses({bool? isPublished}) async {
    try {
      Query query = _firestore.collection('courses');

      if (isPublished != null) {
        query = query.where('isPublished', isEqualTo: isPublished);
      }

      final snapshot = await query.orderBy('createdAt', descending: true).get();
      return snapshot.docs.map((doc) => CourseModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting all courses: $e');
      return [];
    }
  }

  // Create new course
  Future<String?> createCourse(CourseModel course) async {
    try {
      final docRef = await _firestore.collection('courses').add(course.toFirestore());
      print('Course created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error creating course: $e');
      return null;
    }
  }

  // Update existing course
  Future<bool> updateCourse(String courseId, CourseModel course) async {
    try {
      await _firestore.collection('courses').doc(courseId).update(course.toFirestore());
      print('Course updated: $courseId');
      return true;
    } catch (e) {
      print('Error updating course: $e');
      return false;
    }
  }

  // Delete course (hard delete - permanently removes from database)
  Future<bool> deleteCourse(String courseId) async {
    try {
      await _firestore.collection('courses').doc(courseId).delete();
      print('Course deleted: $courseId');
      return true;
    } catch (e) {
      print('Error deleting course: $e');
      return false;
    }
  }

  // Toggle publish status
  Future<bool> togglePublishStatus(String courseId, bool isPublished) async {
    try {
      await _firestore.collection('courses').doc(courseId).update({
        'isPublished': isPublished,
      });
      print('Course publish status updated: $courseId -> $isPublished');
      return true;
    } catch (e) {
      print('Error toggling publish status: $e');
      return false;
    }
  }

  // Add video to course
  Future<bool> addVideoToCourse(String courseId, CourseVideo video) async {
    try {
      final courseDoc = await _firestore.collection('courses').doc(courseId).get();
      if (!courseDoc.exists) {
        throw Exception('Course not found');
      }

      final course = CourseModel.fromFirestore(courseDoc);
      final videos = List<CourseVideo>.from(course.videos);
      videos.add(video);

      // Sort by order
      videos.sort((a, b) => a.order.compareTo(b.order));

      await _firestore.collection('courses').doc(courseId).update({
        'videos': videos.map((v) => v.toMap()).toList(),
      });

      print('Video added to course: $courseId');
      return true;
    } catch (e) {
      print('Error adding video to course: $e');
      return false;
    }
  }

  // Remove video from course
  Future<bool> removeVideoFromCourse(String courseId, String videoId) async {
    try {
      final courseDoc = await _firestore.collection('courses').doc(courseId).get();
      if (!courseDoc.exists) {
        throw Exception('Course not found');
      }

      final course = CourseModel.fromFirestore(courseDoc);
      final videos = course.videos.where((v) => v.videoId != videoId).toList();

      await _firestore.collection('courses').doc(courseId).update({
        'videos': videos.map((v) => v.toMap()).toList(),
      });

      print('Video removed from course: $courseId');
      return true;
    } catch (e) {
      print('Error removing video from course: $e');
      return false;
    }
  }

  // Update video in course
  Future<bool> updateVideoInCourse(String courseId, CourseVideo video) async {
    try {
      final courseDoc = await _firestore.collection('courses').doc(courseId).get();
      if (!courseDoc.exists) {
        throw Exception('Course not found');
      }

      final course = CourseModel.fromFirestore(courseDoc);
      final videos = course.videos.map((v) {
        if (v.videoId == video.videoId) {
          return video;
        }
        return v;
      }).toList();

      // Sort by order
      videos.sort((a, b) => a.order.compareTo(b.order));

      await _firestore.collection('courses').doc(courseId).update({
        'videos': videos.map((v) => v.toMap()).toList(),
      });

      print('Video updated in course: $courseId');
      return true;
    } catch (e) {
      print('Error updating video in course: $e');
      return false;
    }
  }

  // Reorder videos in course
  Future<bool> reorderVideos(String courseId, List<CourseVideo> videos) async {
    try {
      // Update order property
      final reorderedVideos = videos.asMap().entries.map((entry) {
        final index = entry.key;
        final video = entry.value;
        return CourseVideo(
          videoId: video.videoId,
          title: video.title,
          description: video.description,
          bunnyVideoGuid: video.bunnyVideoGuid,
          thumbnailUrl: video.thumbnailUrl,
          durationInSeconds: video.durationInSeconds,
          order: index + 1,
          isFree: video.isFree,
        );
      }).toList();

      await _firestore.collection('courses').doc(courseId).update({
        'videos': reorderedVideos.map((v) => v.toMap()).toList(),
      });

      print('Videos reordered in course: $courseId');
      return true;
    } catch (e) {
      print('Error reordering videos: $e');
      return false;
    }
  }

  // Get course statistics
  Future<Map<String, int>> getCourseStats() async {
    try {
      final snapshot = await _firestore.collection('courses').get();
      final published = snapshot.docs.where((doc) => doc.data()['isPublished'] == true).length;
      final unpublished = snapshot.docs.length - published;

      return {
        'total': snapshot.docs.length,
        'published': published,
        'unpublished': unpublished,
      };
    } catch (e) {
      print('Error getting course stats: $e');
      return {'total': 0, 'published': 0, 'unpublished': 0};
    }
  }
}
