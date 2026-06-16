import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/token_storage.dart';

class ApiClient {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  static String assetUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme) return path;
    return '$baseUrl$path';
  }

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

  static Future<dynamic> patch(String path, dynamic body) async {
    final token = await TokenStorage.getAccessToken();

    final res = await http.patch(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    return _handleResponse(res);
  }

  static Future<dynamic> delete(String path) async {
    final token = await TokenStorage.getAccessToken();

    final res = await http.delete(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    return _handleResponse(res);
  }

  static Future<dynamic> multipartPost(
    String path, {
    required String fieldName,
    required String fileName,
    required Uint8List bytes,
    Map<String, String> fields = const {},
  }) async {
    final token = await TokenStorage.getAccessToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(
      http.MultipartFile.fromBytes(fieldName, bytes, filename: fileName),
    );
    request.fields.addAll(fields);

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handleResponse(res);
  }

  static dynamic _handleResponse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }

    var message = "API Error: ${res.statusCode}";
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded["message"] != null) {
        message = decoded["message"].toString();
      }
    } catch (_) {
      if (res.body.isNotEmpty) message = res.body;
    }
    throw Exception(message);
  }
}
