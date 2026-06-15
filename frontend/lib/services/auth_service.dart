import '../api/auth_api.dart';
import '../core/token_storage.dart';

class AuthService {
  static Future login(
    String walletAddress,
    String signature,
    String nonce, {
    int chainId = 11155111,
    String walletType = "METAMASK",
  }) async {
    final res = await AuthApi.login({
      "walletAddress": walletAddress,
      "signature": signature,
      "nonce": nonce,
      "chainId": chainId,
      "walletType": walletType,
    });

    await TokenStorage.save(res["accessToken"], res["refreshToken"]);

    return res;
  }
}
