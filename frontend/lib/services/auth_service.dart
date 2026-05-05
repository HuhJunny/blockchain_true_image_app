import 'package:frontend/api/auth_api.dart';
import '../core/token_storage.dart';

class AuthService {
  static Future login(
    String walletAddress,
    String signature,
    String nonce,
  ) async {
    final res = await AuthApi.login({
      "walletAddress": walletAddress,
      "signature": signature,
      "nonce": nonce,
      "chainId": 1,
      "walletType": "metamask",
    });

    await TokenStorage.save(res["accessToken"], res["refreshToken"]);

    return res;
  }
}
