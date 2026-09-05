/// Real-time WebSocket — live board updates, notifications, presence.
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api.dart';

typedef WsEventCallback = void Function(Map<String, dynamic> event);

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
  final Map<String, List<WsEventCallback>> _listeners = {};

  bool get isConnected => _connected;

  void connect(String token) {
    _token = token;
    _stopped = false;
    _reconnectDelay = 1;
    _doConnect();
  }

  void disconnect() {
    _stopped = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
  }

  void _doConnect() {
    if (_stopped || _token == null) return;
    try {
      final wsUrl = '${ApiConfig.wsUrl}/ws?token=$_token';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _connected = false;

      _channel!.stream.listen(
        (message) {
          _connected = true;
          _reconnectDelay = 1; // reset on successful message
          try {
            final event = jsonDecode(message as String) as Map<String, dynamic>;
            _handleEvent(event);
          } catch (_) {}
        },
        onDone: () {
          _connected = false;
          _scheduleReconnect();
        },
        onError: (_) {
          _connected = false;
          _scheduleReconnect();
        },
      );

      // Ping kila sekunde 30 — type: ping (sio event: ping)
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_channel != null) {
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
    _reconnectTimer?.cancel();
    final delay = _reconnectDelay;
    _reconnectDelay = (_reconnectDelay * 2).clamp(1, 30);
    _reconnectTimer =
        Timer(Duration(seconds: delay), _doConnect);
  }

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

  /// Sikiliza event maalum.
  void on(String eventType, WsEventCallback callback) {
    _listeners.putIfAbsent(eventType, () => []).add(callback);
  }

  /// Ondoa listener.
  void off(String eventType, WsEventCallback callback) {
    _listeners[eventType]?.remove(callback);
  }

  /// Ondoa WOTE wa event fulani.
  void offAll(String eventType) => _listeners.remove(eventType);

  /// Sikiliza KILA event (wildcard).
  void onAny(WsEventCallback callback) =>
      _listeners.putIfAbsent('*', () => []).add(callback);
}
