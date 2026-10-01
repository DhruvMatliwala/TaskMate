import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../models/message_model.dart';
import '../models/chat_room_model.dart';
import '../models/rating_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Tasks ─────────────────────────────────────────────────────────────────

  /// Stream all open tasks for the map
  Stream<List<TaskModel>> streamOpenTasks() {
    return _db.collection('tasks').snapshots().map((s) {
      final tasks = <TaskModel>[];
      for (final doc in s.docs) {
        try {
          final t = TaskModel.fromFirestore(doc);
          if (t.isOpen) tasks.add(t);
        } catch (e) {
          debugPrint('[FirestoreService] Error parsing open task ${doc.id}: $e');
        }
      }
      tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tasks;
    });
  }

  /// Stream ALL tasks (for home map — shows non-completed too)
  Stream<List<TaskModel>> streamAllActiveTasks() {
    return _db.collection('tasks').snapshots().map((s) {
      final tasks = <TaskModel>[];
      for (final doc in s.docs) {
        try {
          final t = TaskModel.fromFirestore(doc);
          if (t.status != TaskStatus.completed && t.status != TaskStatus.cancelled) {
            tasks.add(t);
          }
        } catch (e) {
          debugPrint('[FirestoreService] Error parsing active task ${doc.id}: $e');
        }
      }
      tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tasks;
    });
  }

  /// Stream tasks posted by a creator (client-side sort — no composite index needed)
  Stream<List<TaskModel>> streamCreatorTasks(String creatorId) {
    return _db
        .collection('tasks')
        .where('creatorId', isEqualTo: creatorId)
        .snapshots()
        .map((s) {
          final tasks = <TaskModel>[];
          for (final doc in s.docs) {
            try {
              tasks.add(TaskModel.fromFirestore(doc));
            } catch (e) {
              debugPrint('[FirestoreService] Error parsing creator task ${doc.id}: $e');
            }
          }
          tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tasks;
        });
  }

  /// Stream tasks accepted by a worker (client-side sort — no composite index needed)
  Stream<List<TaskModel>> streamWorkerTasks(String workerId) {
    return _db
        .collection('tasks')
        .where('workerId', isEqualTo: workerId)
        .snapshots()
        .map((s) {
          final tasks = <TaskModel>[];
          for (final doc in s.docs) {
            try {
              tasks.add(TaskModel.fromFirestore(doc));
            } catch (e) {
              debugPrint('[FirestoreService] Error parsing worker task ${doc.id}: $e');
            }
          }
          tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tasks;
        });
  }

  /// Create a new task
  Future<String> createTask(TaskModel task) async {
    final ref = await _db.collection('tasks').add(task.toMap());
    return ref.id;
  }

  /// Get a single task
  Future<TaskModel?> getTask(String taskId) async {
    final doc = await _db.collection('tasks').doc(taskId).get();
    if (!doc.exists) return null;
    return TaskModel.fromFirestore(doc);
  }

  /// Stream a single task (for live updates)
  Stream<TaskModel?> streamTask(String taskId) {
    return _db
        .collection('tasks')
        .doc(taskId)
        .snapshots()
        .map((doc) => doc.exists ? TaskModel.fromFirestore(doc) : null);
  }

  /// Worker accepts a task
  Future<void> acceptTask({
    required String taskId,
    required String workerId,
    required String workerName,
    String? workerPhotoUrl,
  }) async {
    final chatRoomId = _generateChatRoomId(taskId);
    final taskDoc = await _db.collection('tasks').doc(taskId).get();
    final taskData = taskDoc.data() ?? {};
    final creatorId = taskData['creatorId'] ?? '';
    final creatorName = taskData['creatorName'] ?? 'Job Poster';
    final taskTitle = taskData['title'] ?? 'Task Discussion';

    await _db.collection('tasks').doc(taskId).update({
      'status': TaskStatus.accepted.value,
      'workerId': workerId,
      'workerName': workerName,
      'chatRoomId': chatRoomId,
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    // Create / initialize the chat room with initial unread notification for the creator
    await _db.collection('chats').doc(chatRoomId).set({
      'taskId': taskId,
      'taskTitle': taskTitle,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'workerId': workerId,
      'workerName': workerName,
      'workerPhotoUrl': workerPhotoUrl,
      'participants': [creatorId, workerId],
      'lastMessage': '$workerName accepted your task: $taskTitle',
      'lastMessageSenderId': workerId,
      'lastMessageSenderName': workerName,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadByCreator': true,
      'unreadByWorker': false,
    }, SetOptions(merge: true));

    // Also add system welcome message to subcollection
    await _db.collection('chats').doc(chatRoomId).collection('messages').add({
      'senderId': workerId,
      'senderName': workerName,
      'text': 'Hello! I have accepted your task: $taskTitle. Let\'s coordinate here.',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  /// Worker marks task as in-progress
  Future<void> startTask(String taskId) async {
    await _db.collection('tasks').doc(taskId).update({
      'status': TaskStatus.inProgress.value,
    });
  }

  /// Worker completes a task
  Future<void> completeTask(String taskId) async {
    await _db.collection('tasks').doc(taskId).update({
      'status': TaskStatus.completed.value,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Creator cancels a task
  Future<void> cancelTask(String taskId) async {
    await _db.collection('tasks').doc(taskId).update({
      'status': TaskStatus.cancelled.value,
    });
  }

  /// Update task image URL
  Future<void> updateTaskImage(String taskId, String imageUrl) async {
    await _db.collection('tasks').doc(taskId).update({'imageUrl': imageUrl});
  }

  // ── Bidding ───────────────────────────────────────────────────────────────

  /// Place a bid on a task
  Future<void> placeBid(BidModel bid) async {
    await _db
        .collection('tasks')
        .doc(bid.taskId)
        .collection('bids')
        .doc(bid.workerId) // Each worker can have only one active bid
        .set(bid.toMap());
  }

  /// Stream bids for a specific task
  Stream<List<BidModel>> streamBids(String taskId) {
    return _db
        .collection('tasks')
        .doc(taskId)
        .collection('bids')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map(BidModel.fromFirestore).toList());
  }

  /// Creator accepts a specific bid
  Future<void> acceptBid({
    required String taskId,
    required BidModel bid,
  }) async {
    final chatRoomId = _generateChatRoomId(taskId);
    final taskDoc = await _db.collection('tasks').doc(taskId).get();
    final taskData = taskDoc.data() ?? {};
    final creatorId = taskData['creatorId'] ?? '';
    final creatorName = taskData['creatorName'] ?? 'Job Poster';
    final taskTitle = taskData['title'] ?? 'Task Discussion';

    await _db.collection('tasks').doc(taskId).update({
      'status': TaskStatus.accepted.value,
      'workerId': bid.workerId,
      'workerName': bid.workerName,
      'reward': bid.amount,
      'chatRoomId': chatRoomId,
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    // Create / initialize the chat room with initial unread notification for the worker
    await _db.collection('chats').doc(chatRoomId).set({
      'taskId': taskId,
      'taskTitle': taskTitle,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'workerId': bid.workerId,
      'workerName': bid.workerName,
      'workerPhotoUrl': bid.workerPhotoUrl,
      'participants': [creatorId, bid.workerId],
      'lastMessage': '$creatorName accepted your bid (₹${bid.amount.toInt()})!',
      'lastMessageSenderId': creatorId,
      'lastMessageSenderName': creatorName,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadByCreator': false,
      'unreadByWorker': true,
    }, SetOptions(merge: true));

    // Also add system message
    await _db.collection('chats').doc(chatRoomId).collection('messages').add({
      'senderId': creatorId,
      'senderName': creatorName,
      'text': 'Your bid for ₹${bid.amount.toInt()} has been accepted! Let\'s coordinate here.',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  // ── Live Location ─────────────────────────────────────────────────────────

  /// Worker broadcasts their live GPS to Firestore
  Future<void> updateWorkerLocation({
    required String taskId,
    required double lat,
    required double lng,
  }) async {
    await _db
        .collection('tasks')
        .doc(taskId)
        .collection('live_location')
        .doc('current')
        .set({
          'lat': lat,
          'lng': lng,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Creator streams the worker's live location
  Stream<Map<String, double>?> streamWorkerLocation(String taskId) {
    return _db
        .collection('tasks')
        .doc(taskId)
        .collection('live_location')
        .doc('current')
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          final data = doc.data()!;
          return {
            'lat': (data['lat'] as num).toDouble(),
            'lng': (data['lng'] as num).toDouble(),
          };
        });
  }

  // ── Chat & Messaging ──────────────────────────────────────────────────────

  /// Send a message to a chat room and update metadata & unread status
  Future<void> sendMessage({
    required String chatRoomId,
    required MessageModel message,
    String? taskId,
    String? taskTitle,
    String? creatorId,
    String? creatorName,
    String? workerId,
    String? workerName,
  }) async {
    await _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(message.toMap());

    // Fetch existing chat doc to update participants and unread counters
    final docSnap = await _db.collection('chats').doc(chatRoomId).get();
    final data = docSnap.data() ?? {};
    final cId = creatorId ?? data['creatorId'] ?? '';
    final wId = workerId ?? data['workerId'] ?? '';

    final updateData = <String, dynamic>{
      'lastMessage': message.text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': message.senderId,
      'lastMessageSenderId': message.senderId,
      'lastMessageSenderName': message.senderName,
    };

    if (cId.isNotEmpty) updateData['creatorId'] = cId;
    if (wId.isNotEmpty) updateData['workerId'] = wId;
    if (creatorName != null && creatorName.isNotEmpty) updateData['creatorName'] = creatorName;
    if (workerName != null && workerName.isNotEmpty) updateData['workerName'] = workerName;

    if (cId.isNotEmpty && wId.isNotEmpty) {
      updateData['participants'] = [cId, wId];
      if (message.senderId == cId) {
        updateData['unreadByWorker'] = true;
        updateData['unreadByCreator'] = false;
      } else {
        updateData['unreadByCreator'] = true;
        updateData['unreadByWorker'] = false;
      }
    } else {
      updateData['unreadByCreator'] = true;
      updateData['unreadByWorker'] = true;
    }

    if (taskId != null) updateData['taskId'] = taskId;
    if (taskTitle != null) updateData['taskTitle'] = taskTitle;

    await _db.collection('chats').doc(chatRoomId).set(updateData, SetOptions(merge: true));
  }

  /// Mark chat room as read for a given user
  Future<void> markChatAsRead({
    required String chatRoomId,
    required String userId,
  }) async {
    try {
      final docSnap = await _db.collection('chats').doc(chatRoomId).get();
      if (!docSnap.exists) return;
      final data = docSnap.data() ?? {};
      final creatorId = data['creatorId'];
      final workerId = data['workerId'];

      final update = <String, dynamic>{};
      if (userId == creatorId && data['unreadByCreator'] == true) {
        update['unreadByCreator'] = false;
      }
      if (userId == workerId && data['unreadByWorker'] == true) {
        update['unreadByWorker'] = false;
      }

      if (update.isNotEmpty) {
        await _db.collection('chats').doc(chatRoomId).update(update);
      }
    } catch (e) {
      debugPrint('[FirestoreService] markChatAsRead non-fatal error: $e');
    }
  }

  /// Stream all chat rooms for a user
  Stream<List<ChatRoomModel>> streamUserChatRooms(String userId) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final rooms = snapshot.docs
              .map(ChatRoomModel.fromFirestore)
              .toList();
          rooms.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
          return rooms;
        });
  }

  /// Stream messages in a chat room
  Stream<List<MessageModel>> streamMessages(String chatRoomId) {
    return _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((s) => s.docs.map(MessageModel.fromFirestore).toList());
  }

  // ── Ratings ───────────────────────────────────────────────────────────────

  /// Submit a rating for a worker
  Future<void> rateWorker(RatingModel rating) async {
    // Save individual rating
    await _db.collection('ratings').add(rating.toMap());

    // Update worker's aggregate rating using a transaction
    final workerRef = _db.collection('users').doc(rating.workerId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(workerRef);
      final currentAvg = (snap.data()?['ratingAverage'] ?? 0.0).toDouble();
      final currentCount = (snap.data()?['ratingCount'] ?? 0) as int;

      final newCount = currentCount + 1;
      final newAvg = ((currentAvg * currentCount) + rating.stars) / newCount;

      txn.update(workerRef, {
        'ratingAverage': newAvg,
        'ratingCount': newCount,
      });
    });
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  Stream<UserModel?> streamUser(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<void> incrementTasksPosted(String uid) async {
    await _db.collection('users').doc(uid).update({
      'tasksPosted': FieldValue.increment(1),
    });
  }

  Future<void> incrementTasksCompleted(String uid) async {
    await _db.collection('users').doc(uid).update({
      'tasksCompleted': FieldValue.increment(1),
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _generateChatRoomId(String taskId) {
    return 'chat_$taskId';
  }

  /// Calculate distance between two lat/lng pairs in km
  static double calculateDistance(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    const r = 6371.0; // Earth's radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _toRadians(double deg) => deg * pi / 180;
}
