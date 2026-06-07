import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

class ImageHashResult {
  final String sha256Hash;
  final String pHash;

  const ImageHashResult({
    required this.sha256Hash,
    required this.pHash,
  });
}

class ImageHashService {
  static Future<ImageHashResult> calculate(String imagePath) async {
    final Uint8List bytes = await File(imagePath).readAsBytes();

    final shaHash = _calculateSha256(bytes);
    final perceptualHash = _calculatePHash(bytes);

    return ImageHashResult(
      sha256Hash: shaHash,
      pHash: perceptualHash,
    );
  }

  static String _calculateSha256(List<int> bytes) {
    final digest = sha256.convert(bytes);
    return '0x$digest';
  }

  static String _calculatePHash(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      throw Exception('이미지를 디코딩할 수 없습니다.');
    }

    final resized = img.copyResize(
      decoded,
      width: 32,
      height: 32,
      interpolation: img.Interpolation.average,
    );

    final gray = List.generate(
      32,
      (y) => List.generate(32, (x) {
        final pixel = resized.getPixel(x, y);

        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        return 0.299 * r + 0.587 * g + 0.114 * b;
      }),
    );

    final dctValues = <double>[];

    for (int v = 0; v < 8; v++) {
      for (int u = 0; u < 8; u++) {
        dctValues.add(_dct2D(gray, u, v));
      }
    }

    final valuesForMedian = dctValues.skip(1).toList()..sort();
    final median = valuesForMedian[valuesForMedian.length ~/ 2];

    final bits = dctValues.map((value) => value > median ? 1 : 0).toList();

    final buffer = StringBuffer();

    for (int i = 0; i < bits.length; i += 4) {
      final nibble =
          (bits[i] << 3) |
          (bits[i + 1] << 2) |
          (bits[i + 2] << 1) |
          bits[i + 3];

      buffer.write(nibble.toRadixString(16));
    }

    return buffer.toString();
  }

  static double _dct2D(List<List<double>> pixels, int u, int v) {
    const int size = 32;
    double sum = 0;

    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        sum += pixels[y][x] *
            math.cos(((2 * x + 1) * u * math.pi) / (2 * size)) *
            math.cos(((2 * y + 1) * v * math.pi) / (2 * size));
      }
    }

    final cu = u == 0 ? math.sqrt(1 / size) : math.sqrt(2 / size);
    final cv = v == 0 ? math.sqrt(1 / size) : math.sqrt(2 / size);

    return cu * cv * sum;
  }
}