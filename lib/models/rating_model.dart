import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String id;
  final String taskId;
  final String workerId;
  final String creatorId;
  final double stars;
  final String? comment;
  final DateTime timestamp;

  const RatingModel({
    required this.id,
    required this.taskId,
    required this.workerId,
    required this.creatorId,
    required this.stars,
    this.comment,
    required this.timestamp,
  });

  factory RatingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RatingModel(
      id: doc.id,
      taskId: data['taskId'] ?? '',
      workerId: data['workerId'] ?? '',
      creatorId: data['creatorId'] ?? '',
      stars: (data['stars'] ?? 0.0).toDouble(),
      comment: data['comment'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'workerId': workerId,
      'creatorId': creatorId,
      'stars': stars,
      'comment': comment,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
