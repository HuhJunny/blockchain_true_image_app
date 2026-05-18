import 'package:flutter/material.dart';

class DetailedImagePage extends StatelessWidget {
  final ImageDetailInfo image;

  const DetailedImagePage({
    super.key,
    required this.image,
  });

  void _checkVerification(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${image.title} 검증 정보 확인 기능 연결 예정'),
      ),
    );
  }

  void _deleteImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Image'),
          content: const Text('정말 이 이미지를 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('이미지 삭제 기능 연결 예정'),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final verificationText = '''
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
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz),
          ),
        ],
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
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Original Image Preview',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                    ),
                  ),
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
                style: const TextStyle(
                  color: Color(0xFF6E6E6E),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
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
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                image.description,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Verification Info',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFBABABA),
                  ),
                ),
                child: Text(
                  verificationText.trim(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _checkVerification(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                          color: Color(0xFF959595),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Check Verification',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _deleteImage(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFC0F0F),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Delete Image',
                        style: TextStyle(
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

  const ImageDetailInfo({
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
  });

  factory ImageDetailInfo.sample({
    String title = '한강 야경',
    String price = r'$ 50',
    String description = '직접 촬영한 한강 야경 사진입니다.',
    String status = 'Verified',
    String category = 'LANDSCAPE',
    String timestamp = '2026-03-29T14:31:10Z',
  }) {
    return ImageDetailInfo(
      title: title,
      seller: 'photo_creator',
      price: price,
      saleStatus: status == 'Verified' ? '판매 중' : '검증 대기',
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