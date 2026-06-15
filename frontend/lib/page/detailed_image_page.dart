import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../api/image_api.dart';
import '../api/order_api.dart';
import '../core/network_image_view.dart';

class DetailedImagePage extends StatefulWidget {
  final int? imageId;
  final ImageDetailInfo image;
  final ReownAppKitModal? appKitModal;

  const DetailedImagePage({
    super.key,
    this.imageId,
    required this.image,
    this.appKitModal,
  });

  @override
  State<DetailedImagePage> createState() => _DetailedImagePageState();
}

class _DetailedImagePageState extends State<DetailedImagePage> {
  static const String _sepoliaChain = 'eip155:11155111';
  static const String _contractAddress =
      '0x6154ab54f64106e00C715EBfC7cE6ce8C5dfF9CB';

  bool _isPurchasing = false;

  Future<ImageDetailInfo> _loadDetail() async {
    final id = widget.imageId;
    if (id == null || id < 1) return widget.image;
    final data = await ImageApi.getDetail(id);
    return ImageDetailInfo.fromJson(data);
  }

  ReownAppKitModal get _appKitModal {
    final modal = widget.appKitModal;
    if (modal == null) {
      throw Exception(
        'Wallet session is not available. Go back and connect MetaMask first.',
      );
    }
    return modal;
  }

  List<String> _eip155Accounts(ReownAppKitModal modal) {
    final accounts = modal.session?.getAccounts() ?? const [];
    return accounts.where((account) => account.startsWith('eip155:')).toList();
  }

  String _walletAddress(ReownAppKitModal modal) {
    final accounts = _eip155Accounts(modal);
    for (final account in accounts) {
      if (account.startsWith('$_sepoliaChain:')) {
        return account.split(':').last;
      }
    }

    final address = modal.session?.getAddress('eip155');
    if (address != null && address.isNotEmpty) {
      return address;
    }

    if (accounts.isNotEmpty) {
      return accounts.first.split(':').last;
    }

    throw Exception(
      'No EVM wallet address found in the WalletConnect session.',
    );
  }

  Future<void> _ensureSepolia(ReownAppKitModal modal) async {
    final sepolia = ReownAppKitModalNetworks.getNetworkInfo(
      'eip155',
      '11155111',
    );

    if (sepolia == null) {
      throw Exception('Sepolia network info was not found.');
    }

    await modal.selectChain(sepolia);
  }

  void _assertSepoliaApproved(ReownAppKitModal modal) {
    final approvedChains = modal.session?.getApprovedChains() ?? const [];
    final approvedEip155Chains = approvedChains
        .where((chain) => chain.startsWith('eip155:'))
        .toList();
    if (!approvedEip155Chains.contains(_sepoliaChain)) {
      throw Exception(
        'Current WalletConnect session has not approved Sepolia ($_sepoliaChain). '
        'Please reconnect MetaMask from the wallet login screen. '
        'Approved chains: $approvedChains',
      );
    }
  }

  String _friendlyError(Object error) {
    if (error is ReownAppKitModalException) {
      return error.message.toString();
    }
    return error.toString();
  }

  BigInt _purchasePrice(ImageDetailInfo detail) {
    final raw = detail.price.replaceAll(RegExp(r'[^0-9]'), '');
    final price = BigInt.tryParse(raw);
    if (price == null || price <= BigInt.zero) {
      throw Exception('Image price is not a positive integer.');
    }
    return price;
  }

  String _buildPurchaseImageCalldata(String pHash) {
    const selector = '0xeb7e0788';
    final hashHex = hex.encode(utf8.encode(pHash));
    final paddedHashLength = ((hashHex.length + 63) ~/ 64) * 64;

    final offset = BigInt.from(32).toRadixString(16).padLeft(64, '0');
    final hashLength = (hashHex.length ~/ 2).toRadixString(16).padLeft(64, '0');
    final hashEncoded = hashHex.padRight(paddedHashLength, '0');

    return selector + offset + hashLength + hashEncoded;
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
    if (_isPurchasing) return;

    setState(() {
      _isPurchasing = true;
    });

    try {
      final modal = _appKitModal;
      if (!modal.isConnected || modal.session == null) {
        throw Exception(
          'MetaMask is not connected. Return to Wallet Login and connect first.',
        );
      }
      if (detail.imageHash.isEmpty) {
        throw Exception('Image hash is missing.');
      }

      await _ensureSepolia(modal);
      _assertSepoliaApproved(modal);

      final from = _walletAddress(modal);
      final price = _purchasePrice(detail);
      final data = _buildPurchaseImageCalldata(detail.imageHash);
      final value = '0x${price.toRadixString(16)}';

      debugPrint('[DetailedImagePage] from=$from');
      debugPrint('[DetailedImagePage] to=$_contractAddress');
      debugPrint('[DetailedImagePage] pHash=${detail.imageHash}');
      debugPrint('[DetailedImagePage] value=$value');
      debugPrint('[DetailedImagePage] calldata=$data');

      final result = await modal.request(
        topic: modal.session!.topic,
        chainId: _sepoliaChain,
        switchToChainId: _sepoliaChain,
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [
            {
              'from': from,
              'to': _contractAddress,
              'data': data,
              'value': value,
            },
          ],
        ),
      );

      final txHash = result?.toString().trim() ?? '';
      if (txHash.isEmpty) {
        throw Exception('Transaction hash is missing.');
      }

      final initial = await OrderApi.createOrder(detail.id!, txHash);
      final Map<String, dynamic> order;
      if (initial['status']?.toString() == 'COMPLETED') {
        order = initial;
      } else {
        order = await OrderApi.waitForOrderCompletion(txHash);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Purchase recorded. Order #${order['orderId']} / tx $txHash',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase failed: ${_friendlyError(e)}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _downloadImage(
    BuildContext context,
    ImageDetailInfo detail,
  ) async {
    final imageId = detail.id;
    final orderId = detail.purchasedOrderId;
    if (imageId == null || orderId == null) return;

    try {
      final data = await ImageApi.requestDownload(imageId, orderId);
      if (!context.mounted) return;
      final downloadUrl = (data['downloadUrl'] ?? '').toString();
      final expiresAt = (data['expiresAt'] ?? '').toString();
      showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Download Ready'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Watermarked download URL'),
                  const SizedBox(height: 8),
                  SelectableText(
                    downloadUrl,
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (expiresAt.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Expires at: $expiresAt'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
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
    if (widget.imageId != null) {
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
          return _buildContent(context, snapshot.data ?? widget.image);
        },
      );
    }

    return _buildContent(context, widget.image);
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
                      onPressed: _isPurchasing
                          ? null
                          : image.isOwner
                          ? () => _deleteImage(context, image)
                          : image.purchasedOrderId != null
                          ? () => _downloadImage(context, image)
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
                        _isPurchasing
                            ? 'Purchasing...'
                            : image.isOwner
                            ? 'Delete Image'
                            : image.purchasedOrderId != null
                            ? 'Download Image'
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
  final int? purchasedOrderId;

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
    this.purchasedOrderId,
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
    final purchasedOrderId = (json['purchasedOrderId'] as num?)?.toInt();
    return ImageDetailInfo(
      id: (json['id'] as num?)?.toInt(),
      title: (json['title'] ?? 'Untitled').toString(),
      seller: (seller['nickname'] ?? 'unknown').toString(),
      price: '\$ ${json['price'] ?? 0}',
      saleStatus: purchasedOrderId != null ? 'Purchased' : 'License available',
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
      isSold: false,
      purchasedOrderId: purchasedOrderId,
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
