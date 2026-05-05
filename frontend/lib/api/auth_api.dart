import 'package:frontend/api/api_client.dart';

class AuthApi {
  static Future requestNonce(String address) {
    return ApiClient.post("/auth/wallet/nonce", {
      "walletAddress": address,
      "chainId": 1,
      "walletType": "metamask",
    });
  }

  static Future login(Map data) {
    return ApiClient.post("/auth/wallet/login", data);
  }

  static Future refresh(String refreshToken) {
    return ApiClient.post("/auth/refresh", {"refreshToken": refreshToken});
  }
}
