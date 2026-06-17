import 'dart:typed_data';

import 'api_client.dart';

class ImageApi {
  static Future getImages(int page, {int size = 20, String sort = 'latest'}) {
    return ApiClient.get("/images?page=$page&size=$size&sort=$sort");
  }

  static Future search({
    int page = 0,
    int size = 20,
    String? keyword,
    String? category,
  }) {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (keyword != null && keyword.trim().isNotEmpty) 'keyword': keyword,
      if (category != null && category.trim().isNotEmpty) 'category': category,
    };
    return ApiClient.get('/images/search?${Uri(queryParameters: query).query}');
  }

  static Future getCategories() {
    return ApiClient.get("/images/categories");
  }

  static Future getDetail(int id) {
    return ApiClient.get("/images/$id");
  }

  static Future favorite(int id) {
    return ApiClient.post("/images/$id/favorite", {});
  }

  static Future unfavorite(int id) {
    return ApiClient.delete("/images/$id/favorite");
  }

  static Future deleteImage(int id) {
    return ApiClient.delete("/images/$id");
  }

  static Future updatePrice({
    required int id,
    required BigInt price,
    required String txHash,
  }) {
    return ApiClient.patch("/images/$id/price", {
      "price": price.toString(),
      "txHash": txHash,
    });
  }

  static Future getVerification(int id) {
    return ApiClient.get("/images/$id/verification");
  }

  static Future<Map<String, dynamic>> checkUploadSimilarity({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final result = await ApiClient.multipartPost(
      "/verification/check",
      fieldName: "image",
      fileName: fileName,
      bytes: bytes,
    );
    return Map<String, dynamic>.from(result as Map);
  }

  static Future requestDownload(int id, int orderId) {
    return ApiClient.post("/images/$id/download", {"orderId": orderId});
  }

  static Future upload({
    required String fileName,
    required Uint8List bytes,
    required String title,
    required String description,
    required String price,
    required String category,
    required String deviceId,
    required String capturedAt,
    required String imageHash,
    required String txHash,
    String verificationStatus = 'VERIFIED',
    int? blockNumber,
  }) {
    return ApiClient.multipartPost(
      "/images",
      fieldName: "image",
      fileName: fileName,
      bytes: bytes,
      fields: {
        "title": title,
        "description": description,
        "price": price,
        "category": category,
        "deviceId": deviceId,
        "capturedAt": capturedAt,
        "imageHash": imageHash,
        "txHash": txHash,
        "verificationStatus": verificationStatus,
        if (blockNumber != null) "blockNumber": "$blockNumber",
      },
    );
  }
}
