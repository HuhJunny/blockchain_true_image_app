// user_api.dart
import 'api_client.dart';

class UserApi {
  static Future getMe() {
    return ApiClient.get("/users/me");
  }

  static Future signup(Map data) {
    return ApiClient.post("/users/signup", data);
  }

  static Future getMyImages(int page) {
    return ApiClient.get("/users/me/images?page=$page&size=20");
  }
}
