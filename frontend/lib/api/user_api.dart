// user_api.dart
import 'api_client.dart';

class UserApi {
  static Future getMe() {
    return ApiClient.get("/users/me");
  }

  static Future signup(Map data) {
    return ApiClient.post("/users/signup", data);
  }

  static Future updateProfile(Map data) {
    return ApiClient.patch("/users/profile", data);
  }

  static Future getMyImages(int page) {
    return ApiClient.get("/users/me/images?page=$page&size=20");
  }

  static Future getMyFavorites(int page) {
    return ApiClient.get("/users/me/favorites?page=$page&size=20");
  }

  static Future getMyOrders(int page) {
    return ApiClient.get("/users/me/orders?page=$page&size=20");
  }
}
