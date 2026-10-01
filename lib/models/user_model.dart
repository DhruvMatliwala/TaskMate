import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { creator, worker, both }

class UserModel {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final double ratingAverage;
  final int ratingCount;
  final String? fcmToken;
  final String? photoUrl;
  final int tasksPosted;
  final int tasksCompleted;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.role = UserRole.both,
    this.ratingAverage = 0.0,
    this.ratingCount = 0,
    this.fcmToken,
    this.photoUrl,
    this.tasksPosted = 0,
    this.tasksCompleted = 0,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawRole = data['role']?.toString();
    UserRole parsedRole = UserRole.both;
    if (rawRole == 'worker') {
      parsedRole = UserRole.worker;
    } else if (rawRole == 'creator') {
      parsedRole = UserRole.creator;
    } else {
      parsedRole = UserRole.both;
    }

    return UserModel(
      uid: doc.id,
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      role: parsedRole,
      ratingAverage: (data['ratingAverage'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      fcmToken: data['fcmToken']?.toString(),
      photoUrl: data['photoUrl']?.toString(),
      tasksPosted: (data['tasksPosted'] as num?)?.toInt() ?? 0,
      tasksCompleted: (data['tasksCompleted'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role.name, // 'creator', 'worker', 'both'
      'ratingAverage': ratingAverage,
      'ratingCount': ratingCount,
      'fcmToken': fcmToken,
      'photoUrl': photoUrl,
      'tasksPosted': tasksPosted,
      'tasksCompleted': tasksCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    UserRole? role,
    double? ratingAverage,
    int? ratingCount,
    String? fcmToken,
    String? photoUrl,
    int? tasksPosted,
    int? tasksCompleted,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      ratingAverage: ratingAverage ?? this.ratingAverage,
      ratingCount: ratingCount ?? this.ratingCount,
      fcmToken: fcmToken ?? this.fcmToken,
      photoUrl: photoUrl ?? this.photoUrl,
      tasksPosted: tasksPosted ?? this.tasksPosted,
      tasksCompleted: tasksCompleted ?? this.tasksCompleted,
      createdAt: createdAt,
    );
  }

  String get roleDisplayName {
    switch (role) {
      case UserRole.worker:
        return 'Task Worker';
      case UserRole.creator:
        return 'Task Creator';
      case UserRole.both:
        return 'TaskMate (Both)';
    }
  }

  bool get isWorker => role == UserRole.worker || role == UserRole.both;
  bool get isCreator => role == UserRole.creator || role == UserRole.both;
  bool get isDualRole => role == UserRole.both;
}
