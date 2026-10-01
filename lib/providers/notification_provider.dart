import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/fcm_service.dart';

class InAppNotification {
  final String title;
  final String body;
  final DateTime timestamp;

  InAppNotification({
    required this.title,
    required this.body,
    required this.timestamp,
  });
}

class NotificationProvider extends ChangeNotifier {
  final FcmService _fcmService = FcmService();

  final List<InAppNotification> _notifications = [];
  InAppNotification? _latestNotification;
  bool _showBanner = false;

  // ── Getters ───────────────────────────────────────────────────────────────

  List<InAppNotification> get notifications => List.unmodifiable(_notifications);
  InAppNotification? get latestNotification => _latestNotification;
  bool get showBanner => _showBanner;

  // ── Initialize ────────────────────────────────────────────────────────────

  Future<void> initialize(String uid) async {
    _fcmService.onForegroundMessage = _handleForegroundMessage;
    _fcmService.onMessageOpenedApp = _handleMessageOpenedApp;
    await _fcmService.initialize(uid: uid);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = InAppNotification(
      title: message.notification?.title ?? 'TaskMate',
      body: message.notification?.body ?? '',
      timestamp: DateTime.now(),
    );

    _notifications.add(notification);
    _latestNotification = notification;
    _showBanner = true;
    notifyListeners();

    // Auto-hide banner after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      _showBanner = false;
      _latestNotification = null;
      notifyListeners();
    });
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    // Handle navigation when app is opened from notification
    debugPrint('App opened from notification: ${message.data}');
  }

  void dismissBanner() {
    _showBanner = false;
    _latestNotification = null;
    notifyListeners();
  }

  // ── Send Notification ─────────────────────────────────────────────────────

  Future<void> notifyTaskAccepted({
    required String targetFcmToken,
    required String workerName,
    required String taskTitle,
  }) async {
    await _fcmService.sendNotificationToUser(
      targetFcmToken: targetFcmToken,
      title: '🎉 Task Accepted!',
      body: '$workerName accepted your task "$taskTitle"',
      data: {'type': 'task_accepted'},
    );
  }

  Future<void> notifyTaskCompleted({
    required String targetFcmToken,
    required String taskTitle,
  }) async {
    await _fcmService.sendNotificationToUser(
      targetFcmToken: targetFcmToken,
      title: '✅ Task Completed!',
      body: 'Your task "$taskTitle" has been completed.',
      data: {'type': 'task_completed'},
    );
  }

  Future<void> notifyNewMessage({
    required String targetFcmToken,
    required String senderName,
    required String messagePreview,
  }) async {
    await _fcmService.sendNotificationToUser(
      targetFcmToken: targetFcmToken,
      title: '💬 $senderName',
      body: messagePreview,
      data: {'type': 'new_message'},
    );
  }
}
