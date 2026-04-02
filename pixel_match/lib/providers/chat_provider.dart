import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../models/match_model.dart';
import '../services/chat_service.dart';
import '../config/api_client.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  List<MatchModel> _matches = [];
  List<MessageModel> _messages = [];
  Timer? _pollTimer;
  // ignore: unused_field
  String? _currentChatId;

  List<MatchModel> get matches => _matches;
  List<MessageModel> get messages => _messages;

  Future<void> loadMatches() async {
    final resp = await ApiClient.get('/api/matches');
    if (resp.containsKey('error')) return;
    final list = resp['matches'] as List;
    _matches = list.map((j) => MatchModel.fromJson(j as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  void startListening(String chatId) {
    _currentChatId = chatId;
    _loadMessages(chatId);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollNew(chatId));
  }

  void stopListening() {
    _pollTimer?.cancel();
    _currentChatId = null;
  }

  Future<void> _loadMessages(String chatId) async {
    _messages = await _chatService.getMessages(chatId);
    notifyListeners();
  }

  Future<void> _pollNew(String chatId) async {
    if (_messages.isEmpty) {
      await _loadMessages(chatId);
      return;
    }
    final after = _messages.last.createdAt.toIso8601String();
    final newMsgs = await _chatService.getMessages(chatId, after: after);
    if (newMsgs.isNotEmpty) {
      _messages.addAll(newMsgs);
      notifyListeners();
    }
  }

  Future<void> sendText(String chatId, String text) async {
    await _chatService.sendMessage(chatId, text);
    await _pollNew(chatId);
  }

  Future<void> sendEmote(String chatId, String emoteCode) async {
    await _chatService.sendMessage(chatId, emoteCode, type: 'emote');
    await _pollNew(chatId);
  }

  @override
  void dispose() { _pollTimer?.cancel(); super.dispose(); }
}
