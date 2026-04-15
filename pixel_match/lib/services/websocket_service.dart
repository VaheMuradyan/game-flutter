import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../config/constants.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  // Reconnect state
  static const _initialBackoff = Duration(milliseconds: 500);
  static const _maxBackoff = Duration(seconds: 3);
  static const _heartbeatInterval = Duration(seconds: 10);
  Duration _backoff = _initialBackoff;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _disposed = false;
  bool _manuallyClosed = false;

  // Queued messages sent while the socket is disconnected.
  final List<String> _pendingMessages = [];

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  void connect() {
    if (_disposed) return;
    _manuallyClosed = false;
    _openChannel();
  }

  void _openChannel() {
    _reconnectTimer?.cancel();
    try {
      _channel = WebSocketChannel.connect(
          Uri.parse('${AppConstants.wsBaseUrl}/ws/battle'));
    } catch (e) {
      _scheduleReconnect();
      return;
    }

    _channelSub = _channel!.stream.listen(
      (data) {
        // Reset backoff on any successful message.
        _backoff = _initialBackoff;
        try {
          _controller.add(jsonDecode(data as String) as Map<String, dynamic>);
        } catch (e) {
          _controller.addError(e);
        }
      },
      onError: (Object e) {
        _controller.addError(e);
        _handleDisconnect();
      },
      onDone: _handleDisconnect,
      cancelOnError: true,
    );

    // Flush anything queued while we were down.
    final queued = List<String>.from(_pendingMessages);
    _pendingMessages.clear();
    for (final m in queued) {
      _channel?.sink.add(m);
    }

    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_channel == null) return;
      try {
        _channel!.sink.add(jsonEncode({'type': 'ping'}));
      } catch (_) {
        _handleDisconnect();
      }
    });
  }

  void _handleDisconnect() {
    _heartbeatTimer?.cancel();
    _channelSub?.cancel();
    _channelSub = null;
    _channel = null;
    if (_disposed || _manuallyClosed) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _manuallyClosed) return;
    _reconnectTimer?.cancel();
    final delay = _backoff;
    _reconnectTimer = Timer(delay, _openChannel);
    // Exponential backoff capped at _maxBackoff.
    final nextMs = (_backoff.inMilliseconds * 2)
        .clamp(_initialBackoff.inMilliseconds, _maxBackoff.inMilliseconds);
    _backoff = Duration(milliseconds: nextMs);
  }

  void send(Map<String, dynamic> msg) {
    final encoded = jsonEncode(msg);
    final sink = _channel?.sink;
    if (sink == null) {
      // Buffer so mid-battle drops don't silently lose actions.
      _pendingMessages.add(encoded);
      return;
    }
    try {
      sink.add(encoded);
    } catch (_) {
      _pendingMessages.add(encoded);
      _handleDisconnect();
    }
  }

  void joinQueue(String uid, String characterClass) =>
      send({'type': 'join_queue', 'uid': uid, 'characterClass': characterClass});

  void leaveQueue(String uid) => send({'type': 'leave_queue', 'uid': uid});

  void deployTroop(String battleId, String uid, double x, double y) =>
      send({'type': 'deploy_troop', 'battleId': battleId, 'uid': uid, 'x': x, 'y': y});

  void reportTowerHit(String battleId, String uid, int damage) =>
      send({'type': 'tower_hit', 'battleId': battleId, 'uid': uid, 'damage': damage});

  void dispose() {
    _disposed = true;
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _channelSub?.cancel();
    _channel?.sink.close(ws_status.normalClosure);
    _controller.close();
  }
}
