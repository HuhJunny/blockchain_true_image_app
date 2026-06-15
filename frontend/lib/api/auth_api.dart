import 'api_client.dart';

class AuthApi {
  static Future requestNonce(
    String address, {
    int chainId = 11155111,
    String walletType = "METAMASK",
  }) {
    return ApiClient.post("/auth/wallet/nonce", {
      "walletAddress": address,
      "chainId": chainId,
      "walletType": walletType,
    });
  }

  static Future login(Map data) {
    return ApiClient.post("/auth/wallet/login", data);
  }

  static Future refresh(String refreshToken) {
    return ApiClient.post("/auth/refresh", {"refreshToken": refreshToken});
  }
}
