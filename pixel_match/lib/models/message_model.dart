class MessageModel {
  final String id;
  final String chatId;
  final String senderUid;
  final String text;
  final String messageType; // "text", "emote"
  final DateTime createdAt;

  MessageModel({required this.id, required this.chatId, required this.senderUid,
      required this.text, this.messageType = 'text', required this.createdAt});

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
    id: json['id'] ?? '',
    chatId: json['chatId'] ?? '',
    senderUid: json['senderUid'] ?? '',
    text: json['text'] ?? '',
    messageType: json['messageType'] ?? 'text',
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
  );
}
