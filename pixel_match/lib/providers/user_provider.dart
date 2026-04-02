import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  UserModel? _user;

  UserModel? get user => _user;

  Future<void> loadUser(String uid) async {
    _user = await _userService.getUser(uid);
    notifyListeners();
  }

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  Future<void> updateDisplayName(String name) async {
    _user = await _userService.updateDisplayName(name);
    notifyListeners();
  }

  Future<void> uploadPhoto(String filePath) async {
    _user = await _userService.uploadPhoto(filePath);
    notifyListeners();
  }
}
