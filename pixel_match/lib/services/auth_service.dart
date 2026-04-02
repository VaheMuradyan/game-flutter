import '../config/api_client.dart';
import '../models/user_model.dart';

class AuthService {
  Future<({String token, UserModel user})> register(
      String email, String password) async {
    final resp = await ApiClient.post('/api/auth/register', {
      'email': email,
      'password': password,
    });
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return (
      token: resp['token'] as String,
      user: UserModel.fromJson(resp['user'] as Map<String, dynamic>),
    );
  }

  Future<({String token, UserModel user})> login(
      String email, String password) async {
    final resp = await ApiClient.post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return (
      token: resp['token'] as String,
      user: UserModel.fromJson(resp['user'] as Map<String, dynamic>),
    );
  }

  Future<UserModel> completeOnboarding(
      String displayName, String characterClass) async {
    final resp = await ApiClient.put('/api/onboarding', {
      'displayName': displayName,
      'characterClass': characterClass,
    });
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return UserModel.fromJson(resp['user'] as Map<String, dynamic>);
  }

  Future<UserModel> getMe() async {
    final resp = await ApiClient.get('/api/me');
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return UserModel.fromJson(resp['user'] as Map<String, dynamic>);
  }
}
