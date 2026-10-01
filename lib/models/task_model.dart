import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum TaskStatus { open, accepted, inProgress, completed, cancelled }

enum JobCategory {
  delivery,
  grocery,
  lineStanding,
  physicalLabor,
  techHelp,
}

extension JobCategoryExtension on JobCategory {
  String get value => name;

  String get displayName {
    switch (this) {
      case JobCategory.delivery:
        return 'Delivery & Pickups';
      case JobCategory.grocery:
        return 'Grocery & Shopping';
      case JobCategory.lineStanding:
        return 'Quick Tasks & Line Standing';
      case JobCategory.physicalLabor:
        return 'Physical Labor / Moving';
      case JobCategory.techHelp:
        return 'Tech Help & Setup';
    }
  }

  IconData get icon {
    switch (this) {
      case JobCategory.delivery:
        return Icons.local_shipping_outlined;
      case JobCategory.grocery:
        return Icons.shopping_basket_outlined;
      case JobCategory.lineStanding:
        return Icons.timer_outlined;
      case JobCategory.physicalLabor:
        return Icons.fitness_center_outlined;
      case JobCategory.techHelp:
        return Icons.computer_outlined;
    }
  }

  Color get color {
    switch (this) {
      case JobCategory.delivery:
        return const Color(0xFF38F9D7);
      case JobCategory.grocery:
        return const Color(0xFF43E97B);
      case JobCategory.lineStanding:
        return const Color(0xFFFFD700);
      case JobCategory.physicalLabor:
        return const Color(0xFFFF6584);
      case JobCategory.techHelp:
        return const Color(0xFF6C63FF);
    }
  }

  static JobCategory fromString(String? value) {
    return JobCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => JobCategory.delivery,
    );
  }
}

extension TaskStatusExtension on TaskStatus {
  /// Firestore-safe string value (snake_case). Use this instead of .name.
  String get value {
    switch (this) {
      case TaskStatus.open:
        return 'open';
      case TaskStatus.accepted:
        return 'accepted';
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.completed:
        return 'completed';
      case TaskStatus.cancelled:
        return 'cancelled';
    }
  }

  String get displayName {
    switch (this) {
      case TaskStatus.open:
        return 'Open';
      case TaskStatus.accepted:
        return 'Accepted';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.cancelled:
        return 'Cancelled';
    }
  }

  static TaskStatus fromString(String value) {
    switch (value) {
      case 'accepted':
        return TaskStatus.accepted;
      case 'in_progress':
      case 'inProgress': // handle legacy/built-in enum name
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      case 'cancelled':
        return TaskStatus.cancelled;
      default:
        return TaskStatus.open;
    }
  }
}

class BidModel {
  final String id;
  final String taskId;
  final String workerId;
  final String workerName;
  final String? workerPhotoUrl;
  final double workerRating;
  final double amount;
  final String? message;
  final DateTime timestamp;

  const BidModel({
    required this.id,
    required this.taskId,
    required this.workerId,
    required this.workerName,
    this.workerPhotoUrl,
    this.workerRating = 0.0,
    required this.amount,
    this.message,
    required this.timestamp,
  });

  factory BidModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return BidModel(
      id: doc.id,
      taskId: data['taskId'] ?? '',
      workerId: data['workerId'] ?? '',
      workerName: data['workerName'] ?? '',
      workerPhotoUrl: data['workerPhotoUrl'],
      workerRating: (data['workerRating'] as num?)?.toDouble() ?? 0.0,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      message: data['message'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'workerId': workerId,
      'workerName': workerName,
      'workerPhotoUrl': workerPhotoUrl,
      'workerRating': workerRating,
      'amount': amount,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}

class TaskModel {
  final String id;
  final String title;
  final String description;
  final String creatorId;
  final String creatorName;
  final TaskStatus status;
  final JobCategory category;
  final bool isUrgent;
  final GeoPoint location;
  final String locationName;
  final double minBudget;
  final double maxBudget;
  final double reward; // Final agreed price
  final String? workerId;
  final String? workerName;
  final String? imageUrl;
  final String? chatRoomId;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;

  const TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.creatorId,
    required this.creatorName,
    required this.status,
    required this.category,
    this.isUrgent = false,
    required this.location,
    required this.locationName,
    required this.minBudget,
    required this.maxBudget,
    this.reward = 0.0,
    this.workerId,
    this.workerName,
    this.imageUrl,
    this.chatRoomId,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
  });

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    // Safely parse location (GeoPoint or map representation)
    GeoPoint loc = const GeoPoint(21.1702, 72.8311);
    final rawLoc = data['location'];
    if (rawLoc is GeoPoint) {
      loc = rawLoc;
    } else if (rawLoc is Map) {
      final lat = (rawLoc['latitude'] ?? rawLoc['lat'] as num?)?.toDouble() ?? 21.1702;
      final lng = (rawLoc['longitude'] ?? rawLoc['lng'] as num?)?.toDouble() ?? 72.8311;
      loc = GeoPoint(lat, lng);
    }

    // Robust date parsing
    DateTime? parseTime(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return TaskModel(
      id: doc.id,
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      creatorId: data['creatorId']?.toString() ?? '',
      creatorName: data['creatorName']?.toString() ?? '',
      status: TaskStatusExtension.fromString(data['status']?.toString() ?? 'open'),
      category: JobCategoryExtension.fromString(data['category']?.toString()),
      isUrgent: data['isUrgent'] == true,
      location: loc,
      locationName: data['locationName']?.toString() ?? '',
      minBudget: (data['minBudget'] as num?)?.toDouble() ?? 0.0,
      maxBudget: (data['maxBudget'] as num?)?.toDouble() ?? 0.0,
      reward: (data['reward'] as num?)?.toDouble() ?? 0.0,
      workerId: data['workerId']?.toString(),
      workerName: data['workerName']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
      chatRoomId: data['chatRoomId']?.toString(),
      createdAt: parseTime(data['createdAt']) ?? DateTime.now(),
      acceptedAt: parseTime(data['acceptedAt']),
      completedAt: parseTime(data['completedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'status': status.value,
      'category': category.value,
      'isUrgent': isUrgent,
      'location': location,
      'locationName': locationName,
      'minBudget': minBudget,
      'maxBudget': maxBudget,
      'reward': reward,
      'workerId': workerId,
      'workerName': workerName,
      'imageUrl': imageUrl,
      'chatRoomId': chatRoomId,
      'createdAt': FieldValue.serverTimestamp(),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  TaskModel copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    JobCategory? category,
    bool? isUrgent,
    GeoPoint? location,
    String? locationName,
    double? minBudget,
    double? maxBudget,
    double? reward,
    String? workerId,
    String? workerName,
    String? imageUrl,
    String? chatRoomId,
    DateTime? acceptedAt,
    DateTime? completedAt,
  }) {
    return TaskModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      creatorId: creatorId,
      creatorName: creatorName,
      status: status ?? this.status,
      category: category ?? this.category,
      isUrgent: isUrgent ?? this.isUrgent,
      location: location ?? this.location,
      locationName: locationName ?? this.locationName,
      minBudget: minBudget ?? this.minBudget,
      maxBudget: maxBudget ?? this.maxBudget,
      reward: reward ?? this.reward,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      imageUrl: imageUrl ?? this.imageUrl,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      createdAt: createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  bool get isOpen => status == TaskStatus.open;
  bool get isAccepted => status == TaskStatus.accepted;
  bool get isInProgress => status == TaskStatus.inProgress;
  bool get isCompleted => status == TaskStatus.completed;
}
