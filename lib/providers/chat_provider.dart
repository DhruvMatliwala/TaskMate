import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_room_model.dart';
import '../models/message_model.dart';
import '../services/firestore_service.dart';

class ChatProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<MessageModel> _messages = [];
  StreamSubscription? _messagesSub;
  
  List<ChatRoomModel> _inboxChatRooms = [];
  StreamSubscription? _inboxSub;
  String? _inboxUserId;
  int _totalUnreadCount = 0;

  bool _isLoading = false;
  String? _activeChatRoomId;

  // ── Getters ───────────────────────────────────────────────────────────────

  List<MessageModel> get messages => _messages;
  List<ChatRoomModel> get inboxChatRooms => _inboxChatRooms;
  int get totalUnreadCount => _totalUnreadCount;
  bool get hasUnread => _totalUnreadCount > 0;
  bool get isLoading => _isLoading;
  String? get activeChatRoomId => _activeChatRoomId;

  // ── Inbox Realtime Stream ──────────────────────────────────────────────────

  void initInbox(String userId) {
    if (_inboxUserId == userId && _inboxSub != null) return;
    _inboxUserId = userId;
    _inboxSub?.cancel();

    _inboxSub = _firestoreService.streamUserChatRooms(userId).listen(
      (rooms) {
        _inboxChatRooms = rooms;
        _totalUnreadCount = rooms.where((r) => r.isUnread(userId)).length;
        notifyListeners();
      },
      onError: (err) {
        debugPrint('[ChatProvider] Inbox stream error: $err');
      },
    );
  }

  void stopInbox() {
    _inboxSub?.cancel();
    _inboxSub = null;
    _inboxUserId = null;
    _inboxChatRooms = [];
    _totalUnreadCount = 0;
    notifyListeners();
  }

  // ── Open Chat Room ────────────────────────────────────────────────────────

  void openChatRoom(String chatRoomId, {String? currentUserId}) {
    if (_activeChatRoomId == chatRoomId && _messagesSub != null) return;

    _activeChatRoomId = chatRoomId;
    _messages = [];
    notifyListeners();

    // Mark as read immediately if currentUserId is known
    if (currentUserId != null) {
      _firestoreService.markChatAsRead(
        chatRoomId: chatRoomId,
        userId: currentUserId,
      );
    }

    _messagesSub?.cancel();
    _messagesSub = _firestoreService.streamMessages(chatRoomId).listen((msgs) {
      _messages = msgs;
      notifyListeners();

      // Ensure marked as read when new messages stream in and we are actively viewing
      if (currentUserId != null && _activeChatRoomId == chatRoomId) {
        _firestoreService.markChatAsRead(
          chatRoomId: chatRoomId,
          userId: currentUserId,
        );
      }
    });
  }

  void closeChatRoom() {
    _messagesSub?.cancel();
    _messagesSub = null;
    _activeChatRoomId = null;
    _messages = [];
    notifyListeners();
  }

  // ── Send Message ──────────────────────────────────────────────────────────

  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String text,
    String? taskId,
    String? taskTitle,
    String? creatorId,
    String? workerId,
  }) async {
    if (_activeChatRoomId == null || text.trim().isEmpty) return;

    final message = MessageModel(
      id: '',
      senderId: senderId,
      senderName: senderName,
      text: text.trim(),
      timestamp: DateTime.now(),
    );

    await _firestoreService.sendMessage(
      chatRoomId: _activeChatRoomId!,
      message: message,
      taskId: taskId,
      taskTitle: taskTitle,
      creatorId: creatorId,
      workerId: workerId,
    );
  }

  @override
  void dispose() {
    closeChatRoom();
    stopInbox();
    super.dispose();
  }
}
