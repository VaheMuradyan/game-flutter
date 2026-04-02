import '../config/api_client.dart';

class MatchmakingService {
  Future<({bool isMatch, String? chatId})> recordLike(String likedUid) async {
    final resp = await ApiClient.post('/api/likes', {'likedUid': likedUid});
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return (
      isMatch: resp['match'] == true,
      chatId: resp['chatId'] as String?,
    );
  }

  Future<({int count, int limit, int remaining})> getSwipesToday() async {
    final resp = await ApiClient.get('/api/likes/today');
    return (
      count: resp['count'] as int,
      limit: resp['limit'] as int,
      remaining: resp['remaining'] as int,
    );
  }

  Future<Set<String>> getLikedUids() async {
    final resp = await ApiClient.get('/api/likes/uids');
    final list = resp['likedUids'] as List;
    return list.map((e) => e as String).toSet();
  }
}
