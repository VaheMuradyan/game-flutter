import '../config/api_client.dart';
import '../models/user_model.dart';

class UserService {
  Future<UserModel> getUser(String uid) async {
    final resp = await ApiClient.get('/api/users/$uid');
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return UserModel.fromJson(resp['user'] as Map<String, dynamic>);
  }

  Future<UserModel> updateDisplayName(String name) async {
    final resp = await ApiClient.put('/api/users/profile', {
      'displayName': name,
    });
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return UserModel.fromJson(resp['user'] as Map<String, dynamic>);
  }

  Future<UserModel> uploadPhoto(String filePath) async {
    final resp = await ApiClient.uploadFile('/api/users/photo', filePath, 'photo');
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return UserModel.fromJson(resp['user'] as Map<String, dynamic>);
  }

  Future<List<UserModel>> getEligibleProfiles() async {
    final resp = await ApiClient.get('/api/users/eligible');
    if (resp.containsKey('error')) throw Exception(resp['error']);
    final list = resp['users'] as List;
    return list.map((j) => UserModel.fromJson(j as Map<String, dynamic>)).toList();
  }
}
