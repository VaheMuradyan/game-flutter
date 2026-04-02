import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/matchmaking_service.dart';
import '../config/constants.dart';

class MatchProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  final MatchmakingService _matchmakingService = MatchmakingService();

  List<UserModel> _profiles = [];
  int _currentIndex = 0;
  int _remainingSwipes = AppConstants.dailyFreeSwipes;
  bool _loading = false;
  bool? _lastSwipeWasMatch;
  String? _lastMatchChatId;

  List<UserModel> get profiles => _profiles;
  int get currentIndex => _currentIndex;
  int get remainingSwipes => _remainingSwipes;
  bool get loading => _loading;
  bool get hasProfiles => _currentIndex < _profiles.length;
  UserModel? get currentProfile => hasProfiles ? _profiles[_currentIndex] : null;
  bool? get lastSwipeWasMatch => _lastSwipeWasMatch;
  String? get lastMatchChatId => _lastMatchChatId;

  Future<void> loadProfiles() async {
    _loading = true;
    _lastSwipeWasMatch = null;
    notifyListeners();

    final all = await _userService.getEligibleProfiles();
    final liked = await _matchmakingService.getLikedUids();
    _profiles = all.where((u) => !liked.contains(u.uid)).toList();
    _profiles.shuffle();
    _currentIndex = 0;

    final swipeInfo = await _matchmakingService.getSwipesToday();
    _remainingSwipes = swipeInfo.remaining;

    _loading = false;
    notifyListeners();
  }

  Future<bool> like(String theirUid) async {
    _remainingSwipes--;
    final result = await _matchmakingService.recordLike(theirUid);
    _lastSwipeWasMatch = result.isMatch;
    _lastMatchChatId = result.chatId;
    _currentIndex++;
    notifyListeners();
    return result.isMatch;
  }

  void pass() {
    _lastSwipeWasMatch = null;
    _lastMatchChatId = null;
    _currentIndex++;
    notifyListeners();
  }

  void clearMatchFlag() {
    _lastSwipeWasMatch = null;
    _lastMatchChatId = null;
    notifyListeners();
  }
}
