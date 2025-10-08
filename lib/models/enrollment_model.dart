import 'package:cloud_firestore/cloud_firestore.dart';

class EnrollmentModel {
  final String id;
  final String userId;
  final String userEmail;
  final String courseId;
  final String courseTitle;
  final String transactionId;
  final int amount;
  final DateTime enrolledAt;
  final String status; // 'completed', 'pending', 'rejected'

  EnrollmentModel({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.courseId,
    required this.courseTitle,
    required this.transactionId,
    required this.amount,
    required this.enrolledAt,
    this.status = 'completed', // Default to completed for auto-approval
  });

  // Convert from Firestore document
  factory EnrollmentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return EnrollmentModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      courseId: data['courseId'] ?? '',
      courseTitle: data['courseTitle'] ?? '',
      transactionId: data['transactionId'] ?? '',
      amount: data['amount'] ?? 0,
      enrolledAt: (data['enrolledAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'completed',
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'courseId': courseId,
      'courseTitle': courseTitle,
      'transactionId': transactionId,
      'amount': amount,
      'enrolledAt': Timestamp.fromDate(enrolledAt),
      'status': status,
    };
  }

  // CopyWith method for updates
  EnrollmentModel copyWith({
    String? id,
    String? userId,
    String? userEmail,
    String? courseId,
    String? courseTitle,
    String? transactionId,
    int? amount,
    DateTime? enrolledAt,
    String? status,
  }) {
    return EnrollmentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      courseId: courseId ?? this.courseId,
      courseTitle: courseTitle ?? this.courseTitle,
      transactionId: transactionId ?? this.transactionId,
      amount: amount ?? this.amount,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      status: status ?? this.status,
    );
  }
}
