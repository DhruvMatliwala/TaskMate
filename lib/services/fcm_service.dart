import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Configured with your Web Push VAPID key
  static const String _vapidKey = 'BLosELynbSsyiuKoMmTaNdRIHt7LHtdlNCdKrz_J6fMndzHGxbvU4-MPdKDTaEqfpOe5grHdC-oLuLWOm4Gg6P4';

  // ── Initialize ────────────────────────────────────────────────────────────

  Future<void> initialize({required String uid}) async {
    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('FCM permission denied');
      return;
    }

    // Get FCM token
    String? token;
    if (kIsWeb) {
      try {
        token = await _messaging.getToken(vapidKey: _vapidKey);
      } catch (e) {
        debugPrint('FCM Web token error: $e');
      }
    } else {
      token = await _messaging.getToken();
    }

    if (token != null) {
      await _saveToken(uid, token);
    }

    // Listen for token refreshes
    _messaging.onTokenRefresh.listen((newToken) {
      _saveToken(uid, newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle messages when app is opened from background notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Check if app was opened from a terminated state notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  // ── Token Management ──────────────────────────────────────────────────────

  Future<void> _saveToken(String uid, String token) async {
    await _db.collection('users').doc(uid).update({'fcmToken': token});
    debugPrint('FCM token saved: ${token.substring(0, 20)}...');
  }

  // ── Message Handlers ──────────────────────────────────────────────────────

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground FCM: ${message.notification?.title}');
    // The NotificationProvider will handle showing in-app banners
    onForegroundMessage?.call(message);
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('FCM opened app: ${message.data}');
    onMessageOpenedApp?.call(message);
  }

  // ── Callbacks (set by NotificationProvider) ───────────────────────────────

  Function(RemoteMessage)? onForegroundMessage;
  Function(RemoteMessage)? onMessageOpenedApp;

  // ── Send Notification (via Firestore trigger — use Cloud Functions in prod) 
  // For demo: direct API call using server key (not recommended for production)
  Future<void> sendNotificationToUser({
    required String targetFcmToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    // In production, trigger this via Firebase Cloud Functions.
    // Store a notification doc and let a Cloud Function handle the sending:
    await _db.collection('notification_queue').add({
      'targetToken': targetFcmToken,
      'title': title,
      'body': body,
      'data': data ?? {},
      'createdAt': FieldValue.serverTimestamp(),
      'sent': false,
    });
  }
}
