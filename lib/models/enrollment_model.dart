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
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime? validUntil; // Course access expiry date
  final String? approvedBy; // Admin user ID who approved
  final DateTime? approvedAt; // When payment was approved
  final String? rejectionReason; // Reason if rejected

  EnrollmentModel({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.courseId,
    required this.courseTitle,
    required this.transactionId,
    required this.amount,
    required this.enrolledAt,
    this.status = 'pending', // Default to pending for manual approval
    this.validUntil,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
  });

  // Check if enrollment is still valid
  bool get isValid {
    if (status != 'approved') return false;
    if (validUntil == null) return true; // No expiry
    return DateTime.now().isBefore(validUntil!);
  }

  // Check if expiring soon (within 3 days)
  bool get isExpiringSoon {
    if (validUntil == null) return false;
    final daysUntilExpiry = validUntil!.difference(DateTime.now()).inDays;
    return daysUntilExpiry > 0 && daysUntilExpiry <= 3;
  }

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
      status: data['status'] ?? 'pending',
      validUntil: data['validUntil'] != null
          ? (data['validUntil'] as Timestamp).toDate()
          : null,
      approvedBy: data['approvedBy'],
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      rejectionReason: data['rejectionReason'],
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
      'validUntil': validUntil != null ? Timestamp.fromDate(validUntil!) : null,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectionReason': rejectionReason,
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
    DateTime? validUntil,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectionReason,
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
      validUntil: validUntil ?? this.validUntil,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
