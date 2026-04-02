import '../config/api_client.dart';
import '../models/message_model.dart';

class ChatService {
  Future<List<MessageModel>> getMessages(String chatId, {String? after}) async {
    final path = after != null
        ? '/api/chats/$chatId/messages?after=$after'
        : '/api/chats/$chatId/messages';
    final resp = await ApiClient.get(path);
    if (resp.containsKey('error')) throw Exception(resp['error']);
    final list = resp['messages'] as List;
    return list.map((j) => MessageModel.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<MessageModel> sendMessage(String chatId, String text, {String type = 'text'}) async {
    final resp = await ApiClient.post('/api/chats/$chatId/messages', {
      'text': text,
      'messageType': type,
    });
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return MessageModel.fromJson(resp['message'] as Map<String, dynamic>);
  }
}
