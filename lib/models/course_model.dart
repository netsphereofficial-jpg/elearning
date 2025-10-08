import 'package:cloud_firestore/cloud_firestore.dart';

class CourseVideo {
  final String videoId;
  final String title;
  final String description;
  final String bunnyVideoGuid;
  final String thumbnailUrl;
  final int durationInSeconds;
  final int order;
  final bool isFree;

  CourseVideo({
    required this.videoId,
    required this.title,
    required this.description,
    required this.bunnyVideoGuid,
    required this.thumbnailUrl,
    required this.durationInSeconds,
    required this.order,
    this.isFree = false,
  });

  // Convert from Map
  factory CourseVideo.fromMap(Map<String, dynamic> data) {
    return CourseVideo(
      videoId: data['videoId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      bunnyVideoGuid: data['bunnyVideoGuid'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      durationInSeconds: data['durationInSeconds'] ?? 0,
      order: data['order'] ?? 0,
      isFree: data['isFree'] ?? false,
    );
  }

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'title': title,
      'description': description,
      'bunnyVideoGuid': bunnyVideoGuid,
      'thumbnailUrl': thumbnailUrl,
      'durationInSeconds': durationInSeconds,
      'order': order,
      'isFree': isFree,
    };
  }

  // Format duration as HH:MM:SS or MM:SS
  String get formattedDuration {
    final hours = durationInSeconds ~/ 3600;
    final minutes = (durationInSeconds % 3600) ~/ 60;
    final seconds = durationInSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}

class CourseModel {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final int price;
  final DateTime createdAt;
  final bool isPublished;
  final List<CourseVideo> videos;

  CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.price,
    required this.createdAt,
    this.isPublished = true,
    this.videos = const [],
  });

  // Convert from Firestore document
  factory CourseModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    List<CourseVideo> videosList = [];
    if (data['videos'] != null) {
      videosList = (data['videos'] as List)
          .map((videoData) => CourseVideo.fromMap(videoData as Map<String, dynamic>))
          .toList();
      // Sort by order
      videosList.sort((a, b) => a.order.compareTo(b.order));
    }

    return CourseModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      price: data['price'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isPublished: data['isPublished'] ?? true,
      videos: videosList,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'price': price,
      'createdAt': Timestamp.fromDate(createdAt),
      'isPublished': isPublished,
      'videos': videos.map((video) => video.toMap()).toList(),
    };
  }

  // Computed properties
  int get totalVideos => videos.length;

  int get totalDuration => videos.fold(0, (total, video) => total + video.durationInSeconds);

  String get formattedTotalDuration {
    final hours = totalDuration ~/ 3600;
    final minutes = (totalDuration % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  CourseVideo? get freeVideo {
    try {
      return videos.firstWhere((video) => video.isFree);
    } catch (e) {
      return null;
    }
  }

  List<CourseVideo> get paidVideos => videos.where((video) => !video.isFree).toList();
}
