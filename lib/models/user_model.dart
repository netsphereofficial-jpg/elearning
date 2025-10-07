import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? photoUrl;
  final bool isPremium;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final int maxConcurrentSessions;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.photoUrl,
    this.isPremium = false,
    required this.createdAt,
    this.lastLoginAt,
    this.maxConcurrentSessions = 2,
  });

  // Convert from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      photoUrl: data['photoUrl'],
      isPremium: data['isPremium'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastLoginAt: data['lastLoginAt'] != null
          ? (data['lastLoginAt'] as Timestamp).toDate()
          : null,
      maxConcurrentSessions: data['maxConcurrentSessions'] ?? 2,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'isPremium': isPremium,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'maxConcurrentSessions': maxConcurrentSessions,
    };
  }

  // CopyWith method
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? photoUrl,
    bool? isPremium,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    int? maxConcurrentSessions,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      maxConcurrentSessions: maxConcurrentSessions ?? this.maxConcurrentSessions,
    );
  }
}
