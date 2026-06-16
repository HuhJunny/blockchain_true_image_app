import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../api/image_api.dart';
import '../core/network_image_view.dart';
import 'detailed_image_page.dart';

class GalleryPage extends StatefulWidget {
  final ReownAppKitModal? appKitModal;

  const GalleryPage({super.key, this.appKitModal});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  late Future<List<GalleryItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadItems();
  }

  Future<List<GalleryItem>> _loadItems() async {
    final data = await ImageApi.getImages(0, size: 60);
    return (data as List).map(GalleryItem.fromJson).toList();
  }

  void _refresh() {
    setState(() {
      _future = _loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Gallery',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: FutureBuilder<List<GalleryItem>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 160),
                    Center(
                      child: Text('Failed to load gallery: ${snapshot.error}'),
                    ),
                  ],
                );
              }

              final items = snapshot.data ?? const <GalleryItem>[];
              if (items.isEmpty) {
                return const Center(child: Text('No images yet.'));
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.72,
                ),
                itemBuilder: (context, index) => _GalleryCard(
                  item: items[index],
                  appKitModal: widget.appKitModal,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final GalleryItem item;
  final ReownAppKitModal? appKitModal;

  const _GalleryCard({required this.item, this.appKitModal});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailedImagePage(
              imageId: item.id,
              appKitModal: appKitModal,
              image: ImageDetailInfo.sample(
                title: item.title,
                price: item.price,
              ),
            ),
          ),
        );
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetworkImageView(
                    path: item.thumbnailUrl,
                    fallback: Container(
                      color: const Color(0xFFF3F4F6),
                      child: const Center(child: Text('Thumbnail')),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        item.status,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.price,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item.isSold ? 'Sold' : 'On sale',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GalleryItem {
  final int id;
  final String title;
  final String thumbnailUrl;
  final String price;
  final String status;
  final bool isSold;

  const GalleryItem({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.price,
    required this.status,
    required this.isSold,
  });

  factory GalleryItem.fromJson(dynamic raw) {
    final json = Map<String, dynamic>.from(raw as Map);
    return GalleryItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? 'Untitled').toString(),
      thumbnailUrl: (json['thumbnailUrl'] ?? '').toString(),
      price: '\$ ${json['price'] ?? 0}',
      status: (json['verificationStatus'] ?? 'UNKNOWN').toString(),
      isSold: json['isSold'] == true,
    );
  }
}
