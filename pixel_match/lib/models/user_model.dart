class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String characterClass;
  final String photoUrl;
  final String? blurHash;
  final int level;
  final int xp;
  final String league;
  final int wins;
  final int losses;
  final bool isPremium;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.characterClass,
    this.photoUrl = '',
    this.blurHash,
    this.level = 1,
    this.xp = 0,
    this.league = 'Bronze',
    this.wins = 0,
    this.losses = 0,
    this.isPremium = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      characterClass: json['characterClass'] ?? 'Warrior',
      photoUrl: json['photoUrl'] ?? '',
      blurHash: json['blurHash'] as String?,
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      league: json['league'] ?? 'Bronze',
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      isPremium: json['isPremium'] ?? false,
    );
  }

  bool get isOnboarded => displayName.isNotEmpty;

  UserModel copyWith({
    String? displayName,
    String? characterClass,
    String? photoUrl,
    int? level,
    int? xp,
    String? league,
    int? wins,
    int? losses,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      characterClass: characterClass ?? this.characterClass,
      photoUrl: photoUrl ?? this.photoUrl,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      league: league ?? this.league,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      isPremium: isPremium,
    );
  }
}
