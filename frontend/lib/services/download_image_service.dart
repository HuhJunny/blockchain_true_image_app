import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

import '../api/api_client.dart';

class DownloadImageService {
  static String _resolveDownloadUrl(String rawUrl) {
    if (rawUrl.startsWith('/')) {
      return '${ApiClient.baseUrl}$rawUrl';
    }

    if (rawUrl.startsWith('http://localhost:4000')) {
      return rawUrl.replaceFirst('http://localhost:4000', ApiClient.baseUrl);
    }

    return rawUrl;
  }

  static Future<void> saveWatermarkedImageToGallery(String rawUrl) async {
    final downloadUrl = _resolveDownloadUrl(rawUrl);
    final response = await http.get(Uri.parse(downloadUrl));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('이미지 다운로드 실패: HTTP ${response.statusCode}');
    }

    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        throw Exception('갤러리 저장 권한이 거부되었습니다.');
      }
    }

    await Gal.putImageBytes(
      response.bodyBytes,
      album: 'Block Snap',
    );
  }
}