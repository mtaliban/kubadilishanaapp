/// Firebase Cloud Messaging — arifa za push (kama WhatsApp) + WebSocket bridge.
///
/// Muundo:
///  • Channels 3 za Android (Ujumbe / Mechi / Matangazo) — kila aina ina sauti
///    na mtetemo wake; heads-up inaonyesha juu ya app nyingine (level HIGH).
///  • Background handler (FirebaseMessaging.onBackgroundMessage) — inaendelea
///    kupokea arifa hata app imefungwa kabisa (kama WhatsApp).
///  • Dedupe: FCM na WebSocket zinaweza kutuma event ile ile — kila arifa ina
///    fingerprint (type+id+title) yenye TTL fupi; duplicate inapuuzwa.
///  • showFromEvent(): inaitwa kutoka WebSocketService events — inatengeneza
///    arifa ya ndani wakati app iko foreground/background.
import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

/// Lazima iwe top-level — inasajiliwa na Android mpangilio wa app ikiwa imufungwa.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate: Firebase haijainizialiwa hapa — hiari kwa ajili ya
  // data-only pushes. Arifa zinazoonekana zinatumwa na FCM system tray yenyewe
  // (notification payload) au tunazitengeneza hapa chini kwa data.
  // Kazi maalum: hakuna — Dart isolate hii inaisha mara moja; ni ishara kwa
  // Android layer kuwa handler ipo. Data tunaweza kuihifadhi kwa ajili ya
  // app inayofunguka baadaye (badilisha kuwa durable store kama inahitajika).
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  // LAZY: FirebaseMessaging.instance inadai Firebase.initializeApp() —
  // tusiite wakati wa constructor (inavuruga tests na cold start).
  FirebaseMessaging? _fcmRef;
  FirebaseMessaging get _fcm => _fcmRef ??= FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  Function(Map<String, String>)? onNotificationTapped;

  String? get fcmToken => _fcmToken;

  bool _initialized = false;

  // ── DEDUPE (FCM + WS zinaweza kutuma event ile ile) ─────────────────────────
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

  // ── CHANNELS (kama WhatsApp: kila aina na sauti yake) ────────────────────────
  static const _channelMessages = AndroidNotificationDetails(
    'kubadilishana_messages',
    'Ujumbe',
    channelDescription: 'Ujumbe mpya kutoka kwa wenzako',
    importance: Importance.max,
    priority: Priority.max,
    enableVibration: true,
    playSound: true,
    // Heads-up juu ya app nyingine (bila custom sound — default ya mfumo)
    channelShowBadge: true,
    styleInformation: BigTextStyleInformation(''),
  );

  static const _channelMatches = AndroidNotificationDetails(
    'kubadilishana_matches',
    'Mechi',
    channelDescription: 'Mechi mpya zilizopatikana',
    importance: Importance.max,
    priority: Priority.max,
    enableVibration: true,
    playSound: true,
    channelShowBadge: true,
    styleInformation: BigTextStyleInformation(''),
  );

  static const _channelGeneral = AndroidNotificationDetails(
    'kubadilishana_general',
    'Matangazo',
    channelDescription: 'Matangazo na taarifa za jumla',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    channelShowBadge: true,
    styleInformation: BigTextStyleInformation(''),
  );

  NotificationDetails _detailsFor(String type) {
    final t = type.toLowerCase();
    if (t.contains('message') || t.contains('reply')) {
      return const NotificationDetails(android: _channelMessages);
    }
    if (t.contains('match') || t.contains('verified')) {
      return const NotificationDetails(android: _channelMatches);
    }
    return const NotificationDetails(android: _channelGeneral);
  }

  /// Initialise: request permission, get token, setup listeners + channels.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // ── Channels za Android — lazima zianze kabla ya arifa yoyote ──
    try {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onLocalTap,
      );
      // Kuunda channels mapema (Android 8+)
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'kubadilishana_messages',
          'Ujumbe',
          description: 'Ujumbe mpya kutoka kwa wenzako',
          importance: Importance.max,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'kubadilishana_matches',
          'Mechi',
          description: 'Mechi mpya zilizopatikana',
          importance: Importance.max,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'kubadilishana_general',
          'Matangazo',
          description: 'Matangazo na taarifa za jumla',
          importance: Importance.defaultImportance,
        ),
      );
    } catch (_) {}

    try {
      // Request permission (Android 13+ POST_NOTIFICATIONS)
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        _fcmToken = await _fcm.getToken();
        if (_fcmToken != null) {
          await _registerToken(_fcmToken!);
        }
        _fcm.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          _registerToken(newToken);
        });
      }

      // ── Foreground: arifa ya FCM ikija, ionyeshe kwa channel sahihi ──
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        final type = message.data['type']?.toString() ?? '';
        if (n != null) {
          if (_isDuplicate(type, n.title ?? '', n.body ?? '')) return;
          _show(type: type, title: n.title ?? 'Kubadilishana', body: n.body ?? '',
              payload: message.data);
        } else if (message.data.isNotEmpty) {
          // Data-only push
          _showFromData(message.data);
        }
      });

      // ── Background tap (app ilikuwa background, arifa iliguswa) ──
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _notifyTap(message.data);
      });

      // ── App ilifunguliwa kutoka arifa iliyoguswa app ikiwa IMEFUNGWA ──
      _fcm.getInitialMessage().then((message) {
        if (message != null) _notifyTap(message.data);
      }).catchError((_) {});
    } catch (_) {
      // FCM haifanyi kazi — arifa za ndani bado zinaweza kutumika
    }
  }

  void _onLocalTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final raw = jsonDecode(response.payload!) as Map<String, dynamic>;
      final data = raw.map((k, v) => MapEntry(k, v.toString()));
      _notifyTap(data);
    } catch (_) {}
  }

  void _notifyTap(Map<dynamic, dynamic> data) {
    final safe = data.map((k, v) => MapEntry(k.toString(), v.toString()));
    onNotificationTapped?.call(safe);
  }

  Future<void> _registerToken(String token) async {
    try {
      await ApiService().registerFcmToken(token);
    } catch (_) {}
  }

  // ── KUONYESHA ARIFA ────────────────────────────────────────────────────────

  Future<void> _show({
    required String type,
    required String title,
    required String body,
    Map<dynamic, dynamic>? payload,
  }) async {
    try {
      await _localNotifications.show(
        (type + title).hashCode,
        title,
        body,
        _detailsFor(type),
        payload: jsonEncode(payload ?? {'type': type}),
      );
    } catch (_) {}
  }

  /// Data-only FCM push (bila `notification` block).
  void _showFromData(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final title = data['title']?.toString() ??
        data['notification_title']?.toString() ??
        'Kubadilishana';
    final body = data['body']?.toString() ??
        data['message']?.toString() ??
        data['notification_body']?.toString() ??
        '';
    if (body.isEmpty && title.isEmpty) return;
    if (_isDuplicate(type, title, body)) return;
    _show(type: type, title: title, body: body, payload: data);
  }

  /// Inaitwa kutoka WebSocket events (AuthProvider._setupRealtime).
  /// Inatengeneza arifa ya ndani kama event ni ya arifa-zena.
  void showFromEvent(Map<String, dynamic> event) {
    final type = (event['event'] ?? event['type'])?.toString() ?? '';
    // Event zinazoonyeshwa kama arifa (kama WhatsApp: ujumbe na mechi ndiyo muhimu)
    const notifiable = {
      'notification',
      'notification.new',
      'message.new',
      'message',
      'match.found',
      'match.new',
      'user.verified',
      'payment.approved',
      'payment.rejected',
      'payment.message',
      'payment.reply',
    };
    if (!notifiable.contains(type)) return;

    // Data inaweza kuwa juu (top-level) au ndani ya 'data'/'payload'/'notification'
    Map<String, dynamic> d = event;
    for (final k in const ['data', 'payload', 'notification']) {
      final nested = event[k];
      if (nested is Map) {
        d = nested.map((k2, v2) => MapEntry(k2.toString(), v2));
        break;
      }
    }

    final title = d['title']?.toString() ??
        event['title']?.toString() ??
        _titleForType(type);
    final body = d['body']?.toString() ??
        d['message']?.toString() ??
        event['body']?.toString() ??
        event['message']?.toString() ??
        '';
    if (body.isEmpty && type != 'match.found') return;
    if (_isDuplicate(type, d['id']?.toString() ?? event['id']?.toString() ?? '',
        title + body)) return;

    _show(type: type, title: title, body: body, payload: event);
  }

  static String _titleForType(String type) {
    switch (type) {
      case 'message.new':
      case 'message':
        return 'Ujumbe mpya';
      case 'match.found':
      case 'match.new':
        return 'Mechi mpya imepatikana!';
      case 'user.verified':
        return 'Akaunti yameidhinishwa';
      case 'payment.approved':
        return 'Malipo yameidhinishwa';
      case 'payment.rejected':
        return 'Malipo hayakuidhinishwa';
      default:
        return 'Kubadilishana';
    }
  }

  /// Remove FCM token on logout.
  Future<void> removeToken() async {
    if (_fcmToken != null) {
      try {
        await ApiService().removeFcmToken(_fcmToken!);
      } catch (_) {}
    }
    _recent.clear();
  }
}
