import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_match/models/user_model.dart';

Map<String, dynamic> _baseJson({
  String displayName = 'Name',
  String uid = 'x',
}) =>
    {
      'uid': uid,
      'email': 'x@x.com',
      'displayName': displayName,
      'characterClass': 'Warrior',
      'photoUrl': '',
      'level': 1,
      'xp': 0,
      'league': 'Bronze',
      'wins': 0,
      'losses': 0,
      'isPremium': false,
      'createdAt': '2024-01-01T00:00:00Z',
    };

void main() {
  group('UserModel', () {
    test('fromJson parses correctly', () {
      final user = UserModel.fromJson({
        'uid': 'abc-123',
        'email': 'test@test.com',
        'displayName': 'TestUser',
        'characterClass': 'Mage',
        'photoUrl': '/uploads/photo.jpg',
        'level': 5,
        'xp': 450,
        'league': 'Bronze',
        'wins': 10,
        'losses': 3,
        'isPremium': false,
        'createdAt': '2024-01-01T00:00:00Z',
      });
      expect(user.uid, 'abc-123');
      expect(user.displayName, 'TestUser');
      expect(user.characterClass, 'Mage');
      expect(user.level, 5);
      expect(user.isPremium, false);
    });

    test('isOnboarded returns true when displayName is set', () {
      final user = UserModel.fromJson(_baseJson(displayName: 'Name'));
      expect(user.isOnboarded, true);
    });

    test('isOnboarded returns false when displayName is empty', () {
      final user = UserModel.fromJson(_baseJson(displayName: ''));
      expect(user.isOnboarded, false);
    });

    test('copyWith creates modified copy', () {
      final user = UserModel.fromJson(_baseJson(displayName: 'Old'));
      final updated = user.copyWith(displayName: 'New', level: 10);
      expect(updated.displayName, 'New');
      expect(updated.level, 10);
      expect(updated.uid, 'x');
    });
  });
}
