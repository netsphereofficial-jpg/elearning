import 'package:cloud_firestore/cloud_firestore.dart';

class VideoModel {
  final String id;
  final String title;
  final String description;
  final String cloudflareVideoId;
  final String thumbnailUrl;
  final int durationInSeconds;
  final String category;
  final bool isPremium;
  final DateTime uploadedAt;
  final int viewCount;
  final List<String> tags;

  VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.cloudflareVideoId,
    required this.thumbnailUrl,
    required this.durationInSeconds,
    required this.category,
    this.isPremium = false,
    required this.uploadedAt,
    this.viewCount = 0,
    this.tags = const [],
  });

  // Convert from Firestore document
  factory VideoModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return VideoModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      cloudflareVideoId: data['cloudflareVideoId'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      durationInSeconds: data['durationInSeconds'] ?? 0,
      category: data['category'] ?? 'General',
      isPremium: data['isPremium'] ?? false,
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      viewCount: data['viewCount'] ?? 0,
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'cloudflareVideoId': cloudflareVideoId,
      'thumbnailUrl': thumbnailUrl,
      'durationInSeconds': durationInSeconds,
      'category': category,
      'isPremium': isPremium,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'viewCount': viewCount,
      'tags': tags,
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
