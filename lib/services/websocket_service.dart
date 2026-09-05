/// Real-time WebSocket connection for live board updates + notifications.
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
  final Map<String, WsEventCallback> _listeners = {};

  bool get isConnected => _connected;

  void connect(String token) {
    _token = token;
    _stopped = false;
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
      final wsUrl = '${ApiConfig.wsUrl}?token=$_token';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) {
          _connected = true;
          try {
            final event = jsonDecode(message) as Map<String, dynamic>;
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

      // Ping every 30s to keep alive
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_connected && _channel != null) {
          _channel!.sink.add(jsonEncode({'event': 'ping'}));
        }
      });
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _doConnect);
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = event['event'] as String?;
    if (type == null) return;
    _listeners[type]?.call(event);
    _listeners['*']?.call(event); // wildcard listener
  }

  /// Listen for a specific event type.
  void on(String eventType, WsEventCallback callback) {
    _listeners[eventType] = callback;
  }

  /// Remove listener.
  void off(String eventType) {
    _listeners.remove(eventType);
  }

  /// Listen for ALL events.
  void onAny(WsEventCallback callback) {
    _listeners['*'] = callback;
  }
}
