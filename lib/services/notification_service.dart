/// Firebase Cloud Messaging — arifa za push (kama WhatsApp) + WebSocket bridge.
///
/// Muundo:
///  • Channels 3 za Android (Ujumbe / Mechi / Matangazo).
///  • Canvas large icon: mraba wa rangi + icon ya aina + ES badge chini-kulia.
///  • SubText "Kubadilishana · Malipo · dak 5" kwenye kila arifa.
///  • Action buttons: Jibu/Nimesoma (maoni), Thibitisha/Fungua (malipo-admin),
///    Tazama (malipo-user), Soma tangazo, Tazama mechi.
///  • Background handler (FirebaseMessaging.onBackgroundMessage).
///  • Dedupe: FCM + WS fingerprint na TTL ya sekunde 30.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';
import 'app_navigator.dart';
import 'websocket_service.dart' show resolveNotificationEventType;

/// Lazima iwe top-level — inasajiliwa na Android mpangilio wa app ikiwa imufungwa.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate: ni ishara kwa Android layer kuwa handler ipo.
  // Data-only pushes zinashughulikiwa hapa kama inahitajika.
}

// ─── Canvas large icon cache ──────────────────────────────────────────────────

final _iconBytesCache = <String, Uint8List>{};
ui.Image? _logoImage;
bool _logoTried = false;

Future<ui.Image?> _loadLogoImage() async {
  if (_logoTried) return _logoImage;
  _logoTried = true;
  try {
    final data = await rootBundle.load('assets/images/ess_badge.png');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(), targetWidth: 96, targetHeight: 96);
    _logoImage = (await codec.getNextFrame()).image;
  } catch (_) {}
  return _logoImage;
}

/// Icon kubwa ya mstatili wa rangi + icon ya aina + ES badge chini-kulia.
/// Inatumika kama largeIcon ya notification kwenye Android.
Future<Uint8List> buildNotifLargeIcon(String type, {String? status}) async {
  final key = '$type|$status';
  final cached = _iconBytesCache[key];
  if (cached != null) return cached;

  const s = 192.0;
  const box = Rect.fromLTWH(8, 8, 160, 160);
  const badgeCenter = Offset(155, 155);
  const badgeRadius = 27.0;

  final (iconData, bg, fg) = _iconLook(type, status);

  final rec = ui.PictureRecorder();
  final c = Canvas(rec, const Rect.fromLTWH(0, 0, s, s));

  // Mstatili wa rangi na pembe laini
  c.drawRRect(
    RRect.fromRectAndRadius(box, const Radius.circular(40)),
    Paint()..color = bg,
  );

  // Icon ya aina katikati
  final tp = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: 80,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: fg,
      ),
    ),
  )..layout();
  tp.paint(c, box.center - Offset(tp.width / 2, tp.height / 2));

  // Border nyeupe ya badge
  c.drawCircle(badgeCenter, badgeRadius + 5,
      Paint()..color = Colors.white);

  // ES badge (logo ya app)
  final logo = await _loadLogoImage();
  final badgeRect = Rect.fromCircle(center: badgeCenter, radius: badgeRadius);
  if (logo != null) {
    c.save();
    c.clipPath(Path()..addOval(badgeRect));
    paintImage(canvas: c, rect: badgeRect, image: logo, fit: BoxFit.cover);
    c.restore();
  } else {
    // Fallback: duara la bluu na maandishi "ES"
    c.drawCircle(badgeCenter, badgeRadius, Paint()..color = const Color(0xFF1E40AF));
    final bt = TextPainter(
      textDirection: TextDirection.ltr,
      text: const TextSpan(
        text: 'ES',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    )..layout();
    bt.paint(c, badgeCenter - Offset(bt.width / 2, bt.height / 2));
  }

  final img = await rec.endRecording().toImage(s.toInt(), s.toInt());
  final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!
      .buffer.asUint8List();
  _iconBytesCache[key] = bytes;
  return bytes;
}

(IconData, Color, Color) _iconLook(String type, String? status) {
  return switch (type) {
    'payment.approved'  => (Icons.verified_outlined,       const Color(0xFFD1FAE5), const Color(0xFF047857)),
    'payment.rejected'  => (Icons.cancel_outlined,          const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
    'payment.submitted' ||
    'payment.message'   ||
    'payment.reply'     => (Icons.receipt_long_outlined,   const Color(0xFFD1FAE5), const Color(0xFF047857)),
    'match.found'       ||
    'match.new'         => (Icons.compare_arrows_rounded,  const Color(0xFFFCE7F3), const Color(0xFFBE185D)),
    'user.registered'   => (Icons.person_add_outlined,     const Color(0xFFEDE9FE), const Color(0xFF6D28D9)),
    'announcement'      ||
    'announcement.new'  => (Icons.campaign_outlined,       const Color(0xFFFEF3C7), const Color(0xFFB45309)),
    _                   => (Icons.chat_bubble_outline_rounded, const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
  };
}

// ─── NotificationService ──────────────────────────────────────────────────────

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  FirebaseMessaging? _fcmRef;
  FirebaseMessaging get _fcm => _fcmRef ??= FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  Function(Map<String, String>)? onNotificationTapped;
  String? get fcmToken => _fcmToken;
  bool _initialized = false;

  // ── Dedupe (FCM + WS) ────────────────────────────────────────────────────
  final Map<String, DateTime> _recent = {};
  static const _dedupeTtl = Duration(seconds: 30);

  bool _isDuplicate(String type, String id, String title) {
    final key = '$type|$id|$title';
    final now = DateTime.now();
    _recent.removeWhere((_, t) => now.difference(t) > _dedupeTtl);
    if (_recent.containsKey(key)) return true;
    _recent[key] = now;
    return false;
  }

  // ── Initialise ────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      );
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onLocalTap,
      );
      final android = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'kubadilishana_messages', 'Ujumbe',
        description: 'Ujumbe mpya kutoka kwa wenzako',
        importance: Importance.max,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'kubadilishana_matches', 'Mechi',
        description: 'Mechi mpya zilizopatikana',
        importance: Importance.max,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'kubadilishana_general', 'Matangazo',
        description: 'Matangazo na taarifa za jumla',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));
    } catch (_) {}

    try {
      final settings = await _fcm.requestPermission(
        alert: true, badge: true, sound: true, provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        _fcmToken = await _fcm.getToken();
        if (_fcmToken != null) await _registerToken(_fcmToken!);
        _fcm.onTokenRefresh.listen((t) { _fcmToken = t; _registerToken(t); });
      }

      FirebaseMessaging.onMessage.listen((msg) {
        final n    = msg.notification;
        final type = msg.data['type']?.toString() ?? '';
        if (n != null) {
          if (_isDuplicate(type, n.title ?? '', n.body ?? '')) return;
          _show(type: type, title: n.title ?? 'Kubadilishana',
              body: n.body ?? '', payload: msg.data);
        } else if (msg.data.isNotEmpty) {
          _showFromData(msg.data);
        }
      });

      FirebaseMessaging.onMessageOpenedApp
          .listen((msg) => _notifyTap(msg.data));
      _fcm.getInitialMessage().then((msg) {
        if (msg != null) _notifyTap(msg.data);
      }).catchError((_) {});
    } catch (_) {}
  }

  void _onLocalTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final raw  = jsonDecode(response.payload!) as Map<String, dynamic>;
      final data = raw.map((k, v) => MapEntry(k, v.toString()));
      _notifyTap(data);
    } catch (_) {}
  }

  void _notifyTap(Map<dynamic, dynamic> data) {
    final safe = data.map((k, v) => MapEntry(k.toString(), v.toString()));
    onNotificationTapped?.call(safe);
  }

  Future<void> _registerToken(String token) async {
    try { await ApiService().registerFcmToken(token); } catch (_) {}
  }

  // ── Kuonyesha arifa ───────────────────────────────────────────────────────

  Future<void> _show({
    required String type,
    required String title,
    required String body,
    Map<dynamic, dynamic>? payload,
  }) async {
    try {
      // Canvas large icon (cached)
      ByteArrayAndroidBitmap? largeIcon;
      try {
        final bytes = await buildNotifLargeIcon(
          type, status: payload?['status']?.toString());
        largeIcon = ByteArrayAndroidBitmap(bytes);
      } catch (_) {}

      final categoryLabel = _categoryLabel(type);
      final channelId     = _channelId(type);
      final channelName   = _channelName(channelId);
      final isUrgent      = channelId != 'kubadilishana_general';

      final android = AndroidNotificationDetails(
        channelId, channelName,
        importance:       isUrgent ? Importance.max  : Importance.high,
        priority:         isUrgent ? Priority.max    : Priority.high,
        icon:             'ic_notification',
        largeIcon:        largeIcon ?? const DrawableResourceAndroidBitmap('ic_notification_large'),
        color:            const Color(0xFF1E40AF),
        subText:          'Kubadilishana · $categoryLabel',
        enableLights:     true,
        ledColor:         const Color(0xFF1E40AF),
        ledOnMs:          800,
        ledOffMs:         1500,
        enableVibration:  true,
        playSound:        true,
        channelShowBadge: true,
        when:             DateTime.now().millisecondsSinceEpoch,
        showWhen:         true,
        visibility:       NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle:  title,
          summaryText:   categoryLabel,
        ),
        actions: _actionsFor(type),
        category: (type.startsWith('feedback') || type == 'admin.reply')
            ? AndroidNotificationCategory.message
            : AndroidNotificationCategory.event,
      );

      await _localNotifications.show(
        (type + title).hashCode & 0x7fffffff,
        title,
        body,
        NotificationDetails(android: android),
        payload: jsonEncode(payload ?? {'type': type}),
      );
    } catch (_) {}
  }

  void _showFromData(Map<String, dynamic> data) {
    final type  = data['type']?.toString() ?? '';
    final title = data['title']?.toString() ??
        data['notification_title']?.toString() ?? 'Kubadilishana';
    final body  = data['body']?.toString() ??
        data['message']?.toString() ??
        data['notification_body']?.toString() ?? '';
    if (body.isEmpty && title.isEmpty) return;
    if (_isDuplicate(type, title, body)) return;
    _show(type: type, title: title, body: body, payload: data);
  }

  void showFromEvent(Map<String, dynamic> event) {
    final type = resolveNotificationEventType(event);

    const adminNotifiable = {
      'payment.submitted', 'payment.message',
      'feedback.new', 'user.registered', 'password_reset.new',
      'match.found', 'match.new',
    };
    const userNotifiable = {
      'notification', 'notification.new',
      'message.new', 'message',
      'match.found', 'match.new',
      'user.verified',
      'payment.approved', 'payment.rejected',
      'payment.message', 'payment.reply',
      'feedback.replied', 'admin.reply',
      'announcement', 'announcement.new',
    };

    final isAdmin   = adminPageNotifierAdminStatus();
    final notifiable = isAdmin ? adminNotifiable : userNotifiable;
    if (!notifiable.contains(type)) return;

    Map<String, dynamic> d = event;
    for (final k in const ['data', 'payload', 'notification']) {
      final nested = event[k];
      if (nested is Map) {
        d = nested.map((k2, v2) => MapEntry(k2.toString(), v2));
        break;
      }
    }

    final title = d['title']?.toString() ??
        event['title']?.toString() ?? _titleForType(type);
    final body  = d['body']?.toString() ??
        d['message']?.toString() ??
        event['body']?.toString() ??
        event['message']?.toString() ?? '';
    if (body.isEmpty && type != 'match.found') { return; }
    if (_isDuplicate(type,
        d['id']?.toString() ?? event['id']?.toString() ?? '',
        title + body)) { return; }

    _show(type: type, title: title, body: body, payload: event);
  }

  Future<void> removeToken() async {
    if (_fcmToken != null) {
      try { await ApiService().removeFcmToken(_fcmToken!); } catch (_) {}
    }
    _recent.clear();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static List<AndroidNotificationAction> _actionsFor(String type) {
    // Hakuna vitufe — gusa notification uingie app, fanya ndani.
    return const [];
  }

  static String _categoryLabel(String type) {
    if (type.startsWith('payment'))                          { return 'Malipo'; }
    if (type.startsWith('feedback') || type == 'admin.reply') { return 'Maoni'; }
    if (type.startsWith('match'))                            { return 'Mechi'; }
    if (type.startsWith('announcement'))                     { return 'Tangazo'; }
    if (type == 'user.registered')                           { return 'Watumiaji'; }
    return 'Arifa';
  }

  static String _channelId(String type) {
    if (type.startsWith('payment') ||
        type.startsWith('feedback') ||
        type == 'admin.reply') { return 'kubadilishana_messages'; }
    if (type.startsWith('match') ||
        type == 'user.registered') { return 'kubadilishana_matches'; }
    return 'kubadilishana_general';
  }

  static String _channelName(String id) => switch (id) {
    'kubadilishana_messages' => 'Ujumbe',
    'kubadilishana_matches'  => 'Mechi',
    _                        => 'Matangazo',
  };

  static String _titleForType(String type) => switch (type) {
    'message.new'      || 'message'             => 'Ujumbe mpya',
    'match.found'      || 'match.new'           => 'Mechi mpya imepatikana!',
    'user.verified'                              => 'Akaunti yaidhinishwa',
    'payment.approved'                           => 'Malipo yameidhinishwa ✓',
    'payment.rejected'                           => 'Malipo hayakuidhinishwa',
    'payment.submitted'                          => 'Malipo mapya — angalia',
    'feedback.new'                               => 'Maoni mapya ya mtumiaji',
    'feedback.replied' || 'admin.reply'          => 'Admini amejibu maoni yako',
    'user.registered'                            => 'Mtumiaji mpya amejiunga',
    'password_reset.new'                         => 'Ombi la kubadilisha nywila',
    'announcement'     || 'announcement.new'     => 'Tangazo jipya',
    _                                            => 'Kubadilishana',
  };
}
