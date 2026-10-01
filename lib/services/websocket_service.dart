/// Real-time WebSocket — live board updates, notifications, presence.
///
/// Udhibiti wa makosa (v4):
///  • Reconnect HAINA MWISHO: backoff 1s → 2s → 4s … juu ya 60s. Mtandao
///    ukikatika (au server ipumzike) app inaendelea kujaribu kila dakika
///    moja — live events na arifa hazifi kama zamani (zilikuwa zinakufa
///    baada ya jaribio 5 hadi login mpya). Jitter ndogo inazuia wake
///    mfululizo wa mashine zote kwenye sekunde ile ile server ikirejea.
///    connect() mpya (login / app resume) inaanza upya kwa sekunde 1.
///  • Ujumbe usio String (binary/frame) hauanguki — unapuuzwa salama.
///  • listeners haziongezi mara mbili (on() inagundua callback ile ile).
///  • offAny() kuondoa wildcard listeners (screens zote sasa hutumia dispose).
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api.dart';

typedef WsEventCallback = void Function(Map<String, dynamic> event);

/// Aina HALISI ya event ya WS.
///
/// Backend inatuma envelope: {"event": "notification", "type": "feedback.new",
/// ...} — yaani jina la envelope kwenye 'event' na aina HALISI kwenye 'type'.
/// Wateja wote lazima waitumie hii ili wasome 'feedback.new' badala ya
/// 'notification' (ndiyo ilikuwa chanzo cha arifa za admin zisifikapo).
String resolveNotificationEventType(Map<String, dynamic> event) {
  final outer = (event['event'] ?? event['type'])?.toString() ?? '';
  if (outer == 'notification' || outer == 'notification.new') {
    return (event['type'] ?? event['notification_type'] ?? outer).toString();
  }
  return outer;
}

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._();
  factory WebSocketService() => _instance;
  WebSocketService._();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _connected = false;
  bool _stopped = false;
  String? _token;
  int _reconnectDelay = 1;
  int _reconnectAttempts = 0;
  final Random _random = Random();
  final Map<String, List<WsEventCallback>> _listeners = {};

  /// Kiwango cha juu cha kuchelewa kati ya majaribio ya reconnect (sekunde).
  static const int _maxReconnectDelay = 60;

  bool get isConnected => _connected;

  void connect(String token) {
    _token = token;
    _stopped = false;
    _reconnectDelay = 1;
    _reconnectAttempts = 0; // connect mpya → anza hesabu upya
    _doConnect();
  }

  void disconnect() {
    _stopped = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    try { _channel?.sink.close(); } catch (_) {}
    _channel = null;
    _connected = false;
  }

  void _doConnect() {
    if (_stopped || _token == null) return;
    _pingTimer?.cancel();
    try { _channel?.sink.close(); } catch (_) {}
    _channel = null;
    _connected = false;

    try {
      final wsUrl = '${ApiConfig.wsUrl}/ws?token=$_token';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) {
          _connected = true;
          _reconnectDelay = 1;
          _reconnectAttempts = 0; // tumeunganishwa — hesabu imeisha
          // Ujumbe usio String (binary/frame mbaya) — puuza salama.
          if (message is! String) return;
          try {
            final event = jsonDecode(message) as Map<String, dynamic>;
            _handleEvent(event);
          } catch (_) {} // JSON isiyo sahihi — usianguke
        },
        onDone: () {
          _connected = false;
          _channel = null;
          _pingTimer?.cancel();
          _scheduleReconnect();
        },
        onError: (_) {
          _connected = false;
          _channel = null;
          _pingTimer?.cancel();
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_channel != null && _connected) {
          try {
            _channel!.sink.add(jsonEncode({'type': 'ping'}));
          } catch (_) {}
        }
      });
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_stopped) return;
    // Hakuna MWISHO — backoff inafikia 60s na inabaki hapo; mtandao
    // ukirejea (au server ikirejea) tunaunganishwa bila mtumiaji kufanya
    // chochote. Hii ndiyo nyuma ya "arifa zimekufa" baada ya dakika chache.
    _reconnectAttempts++;

    _reconnectTimer?.cancel();
    // Jitter ±20% — vifaa vyote visijaribu kwa wakati mmoja ukionisha
    // (thundering herd) server ikirejea baada ya kufa.
    final jitter = _reconnectDelay ~/ 5;
    final delay = _reconnectDelay + (_random.nextInt(jitter * 2 + 1) - jitter);
    _reconnectTimer = Timer(Duration(seconds: delay.clamp(1, _maxReconnectDelay)), _doConnect);
    _reconnectDelay = (_reconnectDelay * 2).clamp(1, _maxReconnectDelay);
  }

  /// Test hook: ita event kama ilivyo incoming kwenye socket halisi.
  @visibleForTesting
  void dispatchEventForTest(Map<String, dynamic> event) => _handleEvent(event);

  void _handleEvent(Map<String, dynamic> event) {
    final type = (event['event'] ?? event['type']) as String?;
    if (type == null) return;
    if (type == 'pong') return; // ignore server pong

    // Dispatch to specific listeners
    final specific = _listeners[type];
    if (specific != null) {
      for (final cb in List.of(specific)) {
        try { cb(event); } catch (_) {}
      }
    }
    // Wildcard
    final wild = _listeners['*'];
    if (wild != null) {
      for (final cb in List.of(wild)) {
        try { cb(event); } catch (_) {}
      }
    }
  }

  /// Sikiliza event maalum. Callback ile ile hairudishwi mara mbili
  /// (kuzuia duplicates zinazoongezwa kila initState).
  void on(String eventType, WsEventCallback callback) {
    final list = _listeners.putIfAbsent(eventType, () => []);
    if (!list.contains(callback)) list.add(callback);
  }

  /// Ondoa listener.
  void off(String eventType, WsEventCallback callback) {
    _listeners[eventType]?.remove(callback);
  }

  /// Ondoa WOTE wa event fulani.
  void offAll(String eventType) => _listeners.remove(eventType);

  /// Sikiliza KILA event (wildcard). Dedupe vile vile.
  void onAny(WsEventCallback callback) {
    final list = _listeners.putIfAbsent('*', () => []);
    if (!list.contains(callback)) list.add(callback);
  }

  /// Ondoa wildcard listener.
  void offAny(WsEventCallback callback) {
    _listeners['*']?.remove(callback);
  }

  /// Ondoa listeners ZOTE — logout/session mpya: callbacks za session ya
  /// zamani zisipaswi kuendelea kupokea events (huingiza data za mtumiaji
  /// wa zamani kwenye screens za mpya).
  void clearListeners() => _listeners.clear();
}
