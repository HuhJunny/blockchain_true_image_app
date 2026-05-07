import '../api/api_client.dart';

class ImageApi {
  static Future getImages(int page) {
    return ApiClient.get("/images?page=$page&size=20");
  }

  static Future getDetail(int id) {
    return ApiClient.get("/images/$id");
  }

  static Future favorite(int id) {
    return ApiClient.post("/images/$id/favorite", {});
  }
}
