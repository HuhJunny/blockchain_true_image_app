// order_api.dart
import 'api_client.dart';

class OrderApi {
  static Future<Map<String, dynamic>> createOrder(int imageId, String txHash) async {
    final result = await ApiClient.post("/orders", {
      "imageId": imageId,
      "paymentMethod": "CRYPTO",
      "txHash": txHash,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<Map<String, dynamic>> getOrderStatus(String txHash) async {
    final encoded = Uri.encodeQueryComponent(txHash);
    final result = await ApiClient.get("/orders/status?txHash=$encoded");
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<Map<String, dynamic>> waitForOrderCompletion(
    String txHash, {
    Duration pollInterval = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final deadline = DateTime.now().add(timeout);
    Map<String, dynamic>? last;

    while (DateTime.now().isBefore(deadline)) {
      last = await getOrderStatus(txHash);
      final status = last['status']?.toString() ?? '';

      if (status == 'COMPLETED') {
        return last;
      }
      if (status == 'FAILED') {
        throw Exception(last['message']?.toString() ?? 'Purchase failed.');
      }

      await Future.delayed(pollInterval);
    }

    throw Exception(
      last?['message']?.toString() ?? 'Purchase confirmation timed out.',
    );
  }
}
