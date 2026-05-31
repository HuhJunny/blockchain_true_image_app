import 'package:flutter/material.dart';

import '../api/image_api.dart';
import '../api/order_api.dart';
import '../core/network_image_view.dart';

class DetailedImagePage extends StatelessWidget {
  final int? imageId;
  final ImageDetailInfo image;

  const DetailedImagePage({super.key, this.imageId, required this.image});

  Future<ImageDetailInfo> _loadDetail() async {
    final id = imageId;
    if (id == null || id < 1) return image;
    final data = await ImageApi.getDetail(id);
    return ImageDetailInfo.fromJson(data);
  }

  Future<void> _checkVerification(
    BuildContext context,
    ImageDetailInfo detail,
  ) async {
    if (detail.id == null) return;
    try {
      final data = await ImageApi.getVerification(detail.id!);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification: ${data['verificationStatus']}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Verification failed: $e')));
    }
  }

  Future<void> _buyImage(BuildContext context, ImageDetailInfo detail) async {
    if (detail.id == null) return;
    try {
      final data = await OrderApi.createOrder(detail.id!);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchased. Order #${data['orderId']}')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Purchase failed: $e')));
    }
  }

  void _deleteImage(BuildContext context, ImageDetailInfo detail) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Image'),
          content: const Text('Are you sure you want to delete this image?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                if (detail.id == null) return;
                try {
                  await ImageApi.deleteImage(detail.id!);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Image deleted.')),
                  );
                  Navigator.pop(context, true);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imageId != null) {
      return FutureBuilder<ImageDetailInfo>(
        future: _loadDetail(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.white,
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                title: const Text('Image Detail'),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Failed to load image: ${snapshot.error}'),
                ),
              ),
            );
          }
          return _buildContent(context, snapshot.data ?? image);
        },
      );
    }

    return _buildContent(context, image);
  }

  Widget _buildContent(BuildContext context, ImageDetailInfo image) {
    final verificationText =
        '''
Status: ${image.status}
Category: ${image.category}
Image Hash: ${image.imageHash}
Device ID: ${image.deviceId}
Timestamp: ${image.timestamp}
Tx Hash: ${image.txHash}
Block Number: ${image.blockNumber}
''';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Image Detail',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 238,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: NetworkImageView(
                  path: image.imageUrl,
                  fallback: const Center(child: Text('Original Image Preview')),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                image.title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Seller: ${image.seller}',
                style: const TextStyle(color: Color(0xFF6E6E6E), fontSize: 13),
              ),
              const SizedBox(height: 22),
              Text(
                image.price,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                image.saleStatus,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Description',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                image.description,
                style: const TextStyle(fontSize: 16, height: 1.35),
              ),
              const SizedBox(height: 28),
              const Text(
                'Verification Info',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBABABA)),
                ),
                child: Text(
                  verificationText.trim(),
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _checkVerification(context, image),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFF959595)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Check Verification',
                        style: TextStyle(color: Colors.black, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: image.isOwner
                          ? () => _deleteImage(context, image)
                          : image.isSold
                          ? null
                          : () => _buyImage(context, image),
                      style: FilledButton.styleFrom(
                        backgroundColor: image.isOwner
                            ? const Color(0xFFFC0F0F)
                            : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        image.isOwner
                            ? 'Delete Image'
                            : image.isSold
                            ? 'Sold'
                            : 'Buy Image',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImageDetailInfo {
  final int? id;
  final String title;
  final String seller;
  final String price;
  final String saleStatus;
  final String description;
  final String status;
  final String category;
  final String imageHash;
  final String deviceId;
  final String timestamp;
  final String txHash;
  final String blockNumber;
  final String imageUrl;
  final bool isOwner;
  final bool isSold;

  const ImageDetailInfo({
    this.id,
    required this.title,
    required this.seller,
    required this.price,
    required this.saleStatus,
    required this.description,
    required this.status,
    required this.category,
    required this.imageHash,
    required this.deviceId,
    required this.timestamp,
    required this.txHash,
    required this.blockNumber,
    this.imageUrl = '',
    this.isOwner = false,
    this.isSold = false,
  });

  factory ImageDetailInfo.fromJson(dynamic raw) {
    final json = Map<String, dynamic>.from(raw as Map);
    final verification = Map<String, dynamic>.from(
      (json['verification'] as Map?) ?? const {},
    );
    final seller = Map<String, dynamic>.from(
      (json['seller'] as Map?) ?? const {},
    );
    final status = (verification['status'] ?? '').toString();
    final isSold = json['isSold'] == true;
    return ImageDetailInfo(
      id: (json['id'] as num?)?.toInt(),
      title: (json['title'] ?? 'Untitled').toString(),
      seller: (seller['nickname'] ?? 'unknown').toString(),
      price: '\$ ${json['price'] ?? 0}',
      saleStatus: isSold ? 'Sold' : 'On sale',
      description: (json['description'] ?? '').toString(),
      status: status,
      category: (json['category'] ?? '').toString(),
      imageHash: (verification['imageHash'] ?? '').toString(),
      deviceId: (verification['deviceId'] ?? '').toString(),
      timestamp: (verification['timestamp'] ?? '').toString(),
      txHash: (verification['txHash'] ?? '').toString(),
      blockNumber: (verification['blockNumber'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      isOwner: json['isOwner'] == true,
      isSold: isSold,
    );
  }

  factory ImageDetailInfo.sample({
    String title = 'Sample Image',
    String price = r'$ 50',
    String description = 'Sample image description',
    String status = 'Verified',
    String category = 'LANDSCAPE',
    String timestamp = '2026-03-29T14:31:10Z',
  }) {
    return ImageDetailInfo(
      title: title,
      seller: 'photo_creator',
      price: price,
      saleStatus: status == 'Verified' ? 'On sale' : 'Pending',
      description: description,
      status: status,
      category: category,
      imageHash: '0x8f12ab34cd56ef',
      deviceId: 'device-abc-123',
      timestamp: timestamp,
      txHash: '0xa12345bcd67890',
      blockNumber: '245',
    );
  }
}
