import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  static const _tokenKey = 'jwt_token';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Parses response body and throws [ApiException] on non-2xx status.
  static Map<String, dynamic> _handleResponse(http.Response resp) {
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return body;
    }
    final msg = body['error'] as String? ?? 'Request failed (${resp.statusCode})';
    throw ApiException(resp.statusCode, msg);
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final resp = await http.get(url, headers: await _headers());
    return _handleResponse(resp);
  }

  static Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final resp = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(resp);
  }

  static Future<Map<String, dynamic>> put(
      String path, Map<String, dynamic> body) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final resp = await http.put(
      url,
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(resp);
  }

  /// Upload a file via multipart POST. Returns the response body.
  static Future<Map<String, dynamic>> uploadFile(
      String path, String filePath, String fieldName) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final request = http.MultipartRequest('POST', url);
    final token = await getToken();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    final streamResp = await request.send();
    final resp = await http.Response.fromStream(streamResp);
    return _handleResponse(resp);
  }
}
