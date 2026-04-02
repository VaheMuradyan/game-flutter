import 'user_model.dart';

class MatchModel {
  final String id;
  final String user1Uid;
  final String user2Uid;
  final String chatId;
  final DateTime matchedAt;
  final UserModel? otherUser;

  MatchModel({required this.id, required this.user1Uid, required this.user2Uid,
      required this.chatId, required this.matchedAt, this.otherUser});

  factory MatchModel.fromJson(Map<String, dynamic> json) => MatchModel(
    id: json['id'] ?? '',
    user1Uid: json['user1Uid'] ?? '',
    user2Uid: json['user2Uid'] ?? '',
    chatId: json['chatId'] ?? '',
    matchedAt: DateTime.tryParse(json['matchedAt'] ?? '') ?? DateTime.now(),
    otherUser: json['otherUser'] != null
        ? UserModel.fromJson(json['otherUser']) : null,
  );

  String otherUid(String myUid) => user1Uid == myUid ? user2Uid : user1Uid;
}
