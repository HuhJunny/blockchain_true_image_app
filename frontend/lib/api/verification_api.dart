import 'dart:typed_data';

import 'api_client.dart';

class VerificationApi {
  static Future checkImage({
    required String fileName,
    required Uint8List bytes,
  }) {
    return ApiClient.multipartPost(
      "/verification/check",
      fieldName: "image",
      fileName: fileName,
      bytes: bytes,
    );
  }
}
