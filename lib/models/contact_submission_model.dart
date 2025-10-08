import 'package:cloud_firestore/cloud_firestore.dart';

class ContactSubmissionModel {
  final String id;
  final String name;
  final String email;
  final String message;
  final DateTime submittedAt;
  final bool isRead;

  ContactSubmissionModel({
    required this.id,
    required this.name,
    required this.email,
    required this.message,
    required this.submittedAt,
    this.isRead = false,
  });

  // Convert from Firestore document
  factory ContactSubmissionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ContactSubmissionModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      message: data['message'] ?? '',
      submittedAt: (data['submittedAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'message': message,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'isRead': isRead,
    };
  }

  // CopyWith method
  ContactSubmissionModel copyWith({
    String? id,
    String? name,
    String? email,
    String? message,
    DateTime? submittedAt,
    bool? isRead,
  }) {
    return ContactSubmissionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      message: message ?? this.message,
      submittedAt: submittedAt ?? this.submittedAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
