import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/message_model.dart';
import '../models/match_model.dart';
import '../services/chat_service.dart';
import '../config/api_client.dart';
import '../config/constants.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  List<MatchModel> _matches = [];
  List<MessageModel> _messages = [];
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;

  List<MatchModel> get matches => _matches;
  List<MessageModel> get messages => _messages;

  Future<void> loadMatches() async {
    final resp = await ApiClient.get('/api/matches');
    final list = resp['matches'] as List;
    _matches = list.map((j) => MatchModel.fromJson(j as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  void startListening(String chatId) {
    _loadMessages(chatId);
    _connectWebSocket(chatId);
  }

  void _connectWebSocket(String chatId) {
    final uri = Uri.parse('${AppConstants.wsBaseUrl}/ws/chat/$chatId');
    _channel = WebSocketChannel.connect(uri);
    _wsSub = _channel!.stream.listen(
      (data) {
        final json = jsonDecode(data as String) as Map<String, dynamic>;
        final msg = MessageModel.fromJson(json);
        _messages.add(msg);
        notifyListeners();
      },
      onError: (_) {},
      onDone: () {},
    );
  }

  void stopListening() {
    _wsSub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> _loadMessages(String chatId) async {
    _messages = await _chatService.getMessages(chatId);
    notifyListeners();
  }

  Future<void> sendText(String chatId, String text) async {
    await _chatService.sendMessage(chatId, text);
  }

  Future<void> sendEmote(String chatId, String emoteCode) async {
    await _chatService.sendMessage(chatId, emoteCode, type: 'emote');
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
