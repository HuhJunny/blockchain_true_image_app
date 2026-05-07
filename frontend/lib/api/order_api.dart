// order_api.dart
import 'api_client.dart';

class OrderApi {
  static Future createOrder(int imageId) {
    return ApiClient.post("/orders", {
      "imageId": imageId,
      "paymentMethod": "CRYPTO",
    });
  }
}
