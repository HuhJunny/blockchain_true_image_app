import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/token_storage.dart';

class ApiClient {
  static const baseUrl = "http://localhost:4000";

  static Future<dynamic> get(String path) async {
    final token = await TokenStorage.getAccessToken();

    final res = await http.get(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    return _handleResponse(res);
  }

  static Future<dynamic> post(String path, dynamic body) async {
    final token = await TokenStorage.getAccessToken();

    final res = await http.post(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    return _handleResponse(res);
  }

  static dynamic _handleResponse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    } else {
      throw Exception("API Error: ${res.statusCode}");
    }
  }
}
