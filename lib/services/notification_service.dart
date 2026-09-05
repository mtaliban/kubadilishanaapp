/// Firebase Cloud Messaging — receive push notifications + register token.
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  Function(Map<String, String>)? onNotificationTapped;

  String? get fcmToken => _fcmToken;

  /// Initialise: request permission, get token, setup listeners.
  Future<void> init() async {
    try {
      // Request permission
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        _fcmToken = await _fcm.getToken();
        if (_fcmToken != null) {
          await _registerToken(_fcmToken!);
        }
        _fcm.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          _registerToken(newToken);
        });
      }
    } catch (_) {
      // FCM haitaanguka app kama haijafanya kazi
    }

    try {
      // Setup local notifications
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      await _localNotifications.initialize(
        const InitializationSettings(android: androidSettings),
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null) {
            try {
              final raw = jsonDecode(response.payload!) as Map<String, dynamic>;
              // Convert to Map<String, String> safely
              final data = raw.map((k, v) => MapEntry(k, v.toString()));
              onNotificationTapped?.call(data);
            } catch (_) {}
          }
        },
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background tap
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        try {
          final data = message.data.map((k, v) => MapEntry(k, v.toString()));
          onNotificationTapped?.call(data);
        } catch (_) {}
      });
    } catch (_) {
      // Local notifications haitaanguka app
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await ApiService().registerFcmToken(token);
    } catch (_) {}
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Show local notification
    const androidDetails = AndroidNotificationDetails(
      'kubadilishana',
      'Kubadilishana',
      channelDescription: 'Kubadilishana notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  /// Remove FCM token on logout.
  Future<void> removeToken() async {
    if (_fcmToken != null) {
      try {
        await ApiService().removeFcmToken(_fcmToken!);
      } catch (_) {}
    }
  }
}
