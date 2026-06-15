import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../api/api_client.dart';

class NetworkImageView extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final Widget fallback;

  const NetworkImageView({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.fallback = const Center(child: Text('Thumbnail')),
  });

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return fallback;

    final url = ApiClient.assetUrl(path);
    if (Uri.parse(url).path.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(
        url,
        fit: fit,
        placeholderBuilder: (_) => fallback,
      );
    }

    return Image.network(
      url,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
