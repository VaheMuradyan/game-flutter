class BattleModel {
  final String id;
  final String player1Uid;
  final String player2Uid;
  final String winnerUid;
  final int player1Health;
  final int player2Health;
  final int duration;
  final int xpAwarded;
  final DateTime createdAt;

  BattleModel({
    required this.id, required this.player1Uid, required this.player2Uid,
    required this.winnerUid, required this.player1Health, required this.player2Health,
    required this.duration, required this.xpAwarded, required this.createdAt,
  });

  factory BattleModel.fromJson(Map<String, dynamic> json) => BattleModel(
    id: json['id'] ?? '',
    player1Uid: json['player1Uid'] ?? '',
    player2Uid: json['player2Uid'] ?? '',
    winnerUid: json['winnerUid'] ?? '',
    player1Health: json['player1Health'] ?? 0,
    player2Health: json['player2Health'] ?? 0,
    duration: json['duration'] ?? 0,
    xpAwarded: json['xpAwarded'] ?? 0,
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
  );
}
