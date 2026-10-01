import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final String taskId;
  final String taskTitle;
  final String creatorId;
  final String creatorName;
  final String? creatorPhotoUrl;
  final String workerId;
  final String workerName;
  final String? workerPhotoUrl;
  final String lastMessage;
  final String lastMessageSenderId;
  final DateTime lastMessageTime;
  final bool unreadByCreator;
  final bool unreadByWorker;
  final List<String> participants;

  const ChatRoomModel({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.creatorId,
    required this.creatorName,
    this.creatorPhotoUrl,
    required this.workerId,
    required this.workerName,
    this.workerPhotoUrl,
    required this.lastMessage,
    required this.lastMessageSenderId,
    required this.lastMessageTime,
    this.unreadByCreator = false,
    this.unreadByWorker = false,
    required this.participants,
  });

  factory ChatRoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final participantsList = (data['participants'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return ChatRoomModel(
      id: doc.id,
      taskId: data['taskId'] ?? '',
      taskTitle: data['taskTitle'] ?? 'Task Discussion',
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? 'Task Poster',
      creatorPhotoUrl: data['creatorPhotoUrl'],
      workerId: data['workerId'] ?? '',
      workerName: data['workerName'] ?? 'Worker',
      workerPhotoUrl: data['workerPhotoUrl'],
      lastMessage: data['lastMessage'] ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      lastMessageTime: parseDate(data['lastMessageTime'] ?? data['lastMessageAt']),
      unreadByCreator: data['unreadByCreator'] ?? false,
      unreadByWorker: data['unreadByWorker'] ?? false,
      participants: participantsList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'taskTitle': taskTitle,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'creatorPhotoUrl': creatorPhotoUrl,
      'workerId': workerId,
      'workerName': workerName,
      'workerPhotoUrl': workerPhotoUrl,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadByCreator': unreadByCreator,
      'unreadByWorker': unreadByWorker,
      'participants': participants,
    };
  }

  String otherParticipantName(String myUid) {
    return myUid == creatorId ? workerName : creatorName;
  }

  String otherParticipantRole(String myUid) {
    return myUid == creatorId ? 'Worker' : 'Job Poster';
  }

  String? otherParticipantPhoto(String myUid) {
    return myUid == creatorId ? workerPhotoUrl : creatorPhotoUrl;
  }

  bool isUnread(String myUid) {
    if (lastMessageSenderId.isNotEmpty && lastMessageSenderId == myUid) {
      return false;
    }
    if (myUid == creatorId) return unreadByCreator;
    if (myUid == workerId) return unreadByWorker;
    if (participants.contains(myUid)) {
      return unreadByCreator || unreadByWorker;
    }
    return false;
  }
}
