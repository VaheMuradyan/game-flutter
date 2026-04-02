import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../config/api_client.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  String _selectedClass = '';

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isOnboarded => _user != null && _user!.isOnboarded;
  String get selectedClass => _selectedClass;

  void setSelectedClass(String cls) {
    _selectedClass = cls;
    notifyListeners();
  }

  Future<void> tryAutoLogin() async {
    final token = await ApiClient.getToken();
    if (token == null) return;
    try {
      _user = await _authService.getMe();
      notifyListeners();
    } catch (_) {
      await ApiClient.clearToken();
    }
  }

  Future<bool> register(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _authService.register(email, password);
      await ApiClient.saveToken(result.token);
      _user = result.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _authService.login(email, password);
      await ApiClient.saveToken(result.token);
      _user = result.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeOnboarding(String displayName) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authService.completeOnboarding(displayName, _selectedClass);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await ApiClient.clearToken();
    _user = null;
    _selectedClass = '';
    notifyListeners();
  }
}
