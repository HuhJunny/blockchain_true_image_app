import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static Future<void> save(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("accessToken", access);
    await prefs.setString("refreshToken", refresh);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("accessToken");
  }
}
