import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/constants.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  void connect() {
    _channel = WebSocketChannel.connect(Uri.parse('${AppConstants.wsBaseUrl}/ws/battle'));
    _channel!.stream.listen(
      (data) => _controller.add(jsonDecode(data as String)),
      onError: (e) => _controller.addError(e),
      onDone: () {},
    );
  }

  void send(Map<String, dynamic> msg) => _channel?.sink.add(jsonEncode(msg));

  void joinQueue(String uid, String characterClass) =>
      send({'type': 'join_queue', 'uid': uid, 'characterClass': characterClass});

  void leaveQueue(String uid) => send({'type': 'leave_queue', 'uid': uid});

  void deployTroop(String battleId, String uid, double x, double y) =>
      send({'type': 'deploy_troop', 'battleId': battleId, 'uid': uid, 'x': x, 'y': y});

  void reportTowerHit(String battleId, String uid, int damage) =>
      send({'type': 'tower_hit', 'battleId': battleId, 'uid': uid, 'damage': damage});

  void dispose() => _channel?.sink.close();
}
