import 'package:cloud_firestore/cloud_firestore.dart';

class WatchSessionModel {
  final String id;
  final String userId;
  final String videoId;
  final int lastWatchedPosition; // in seconds
  final bool isCompleted;
  final DateTime lastWatchedAt;
  final DateTime? completedAt;
  final int totalWatchTime; // in seconds
  final String deviceId;
  final String? ipAddress;

  WatchSessionModel({
    required this.id,
    required this.userId,
    required this.videoId,
    this.lastWatchedPosition = 0,
    this.isCompleted = false,
    required this.lastWatchedAt,
    this.completedAt,
    this.totalWatchTime = 0,
    required this.deviceId,
    this.ipAddress,
  });

  // Convert from Firestore document
  factory WatchSessionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WatchSessionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      videoId: data['videoId'] ?? '',
      lastWatchedPosition: data['lastWatchedPosition'] ?? 0,
      isCompleted: data['isCompleted'] ?? false,
      lastWatchedAt: (data['lastWatchedAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      totalWatchTime: data['totalWatchTime'] ?? 0,
      deviceId: data['deviceId'] ?? '',
      ipAddress: data['ipAddress'],
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'videoId': videoId,
      'lastWatchedPosition': lastWatchedPosition,
      'isCompleted': isCompleted,
      'lastWatchedAt': Timestamp.fromDate(lastWatchedAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'totalWatchTime': totalWatchTime,
      'deviceId': deviceId,
      'ipAddress': ipAddress,
    };
  }

  // Calculate progress percentage
  double calculateProgress(int videoDuration) {
    if (videoDuration == 0) return 0.0;
    return (lastWatchedPosition / videoDuration).clamp(0.0, 1.0);
  }

  // CopyWith method
  WatchSessionModel copyWith({
    String? id,
    String? userId,
    String? videoId,
    int? lastWatchedPosition,
    bool? isCompleted,
    DateTime? lastWatchedAt,
    DateTime? completedAt,
    int? totalWatchTime,
    String? deviceId,
    String? ipAddress,
  }) {
    return WatchSessionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      videoId: videoId ?? this.videoId,
      lastWatchedPosition: lastWatchedPosition ?? this.lastWatchedPosition,
      isCompleted: isCompleted ?? this.isCompleted,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      completedAt: completedAt ?? this.completedAt,
      totalWatchTime: totalWatchTime ?? this.totalWatchTime,
      deviceId: deviceId ?? this.deviceId,
      ipAddress: ipAddress ?? this.ipAddress,
    );
  }
}
