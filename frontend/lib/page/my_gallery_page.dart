import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../core/network_image_view.dart';
import '../api/user_api.dart';
import 'detailed_image_page.dart';

class MyGalleryPage extends StatefulWidget {
  final ReownAppKitModal? appKitModal;

  const MyGalleryPage({super.key, this.appKitModal});

  @override
  State<MyGalleryPage> createState() => _MyGalleryPageState();
}

class _MyGalleryPageState extends State<MyGalleryPage> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<MyGalleryItem>> _future;

  String _selectedFilter = 'ALL';
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _future = _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<MyGalleryItem>> _loadItems() async {
    final data = await UserApi.getMyImages(0);
    return (data as List).map(MyGalleryItem.fromJson).toList();
  }

  void _refresh() {
    setState(() {
      _future = _loadItems();
    });
  }

  List<MyGalleryItem> _filterItems(List<MyGalleryItem> items) {
    return items.where((item) {
      final matchesSearch = item.title.toLowerCase().contains(
        _searchText.toLowerCase(),
      );
      final matchesFilter = switch (_selectedFilter) {
        'VERIFIED' => item.status == GalleryStatus.verified,
        'PENDING' => item.status == GalleryStatus.pending,
        'SOLD' => item.isSold,
        _ => true,
      };
      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                for (final filter in const [
                  'ALL',
                  'VERIFIED',
                  'PENDING',
                  'SOLD',
                ])
                  ListTile(
                    title: Text(filter),
                    trailing: _selectedFilter == filter
                        ? const Icon(Icons.check, color: Colors.black)
                        : null,
                    onTap: () {
                      setState(() => _selectedFilter = filter);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<MyGalleryItem>>(
          future: _future,
          builder: (context, snapshot) {
            final items = _filterItems(
              snapshot.data ?? const <MyGalleryItem>[],
            );
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Gallery',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() => _searchText = value.trim());
                            },
                            decoration: InputDecoration(
                              hintText: 'Search my uploads',
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.black45,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 44,
                        child: FilledButton(
                          onPressed: _showFilterSheet,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                          ),
                          child: const Text('Filter'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (snapshot.hasError)
                    Center(
                      child: Text('Failed to load uploads: ${snapshot.error}'),
                    )
                  else if (items.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Text('No uploads found.'),
                      ),
                    )
                  else
                    GridView.builder(
                      itemCount: items.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.73,
                          ),
                      itemBuilder: (context, index) {
                        return _MyGalleryCard(
                          item: items[index],
                          appKitModal: widget.appKitModal,
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MyGalleryCard extends StatelessWidget {
  final MyGalleryItem item;
  final ReownAppKitModal? appKitModal;

  const _MyGalleryCard({required this.item, this.appKitModal});

  @override
  Widget build(BuildContext context) {
    final statusText = item.status == GalleryStatus.verified
        ? 'VERIFIED'
        : 'PENDING';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final changed = await Navigator.push(
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
        if (changed == true && context.mounted) {
          final state = context.findAncestorStateOfType<_MyGalleryPageState>();
          state?._refresh();
        }
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 7,
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
                    left: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (item.isSold)
                    Positioned(
                      right: 7,
                      top: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'SOLD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
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
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
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
                      item.createdAt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
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

class MyGalleryItem {
  final int id;
  final String title;
  final String price;
  final String createdAt;
  final String thumbnailUrl;
  final GalleryStatus status;
  final bool isSold;

  const MyGalleryItem({
    required this.id,
    required this.title,
    required this.price,
    required this.createdAt,
    required this.thumbnailUrl,
    required this.status,
    required this.isSold,
  });

  factory MyGalleryItem.fromJson(dynamic raw) {
    final json = Map<String, dynamic>.from(raw as Map);
    final status = (json['verificationStatus'] ?? '').toString().toUpperCase();
    return MyGalleryItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? 'Untitled').toString(),
      price: '\$ ${json['price'] ?? 0}',
      createdAt: (json['createdAt'] ?? '').toString(),
      thumbnailUrl: (json['thumbnailUrl'] ?? '').toString(),
      status: status == 'VERIFIED'
          ? GalleryStatus.verified
          : GalleryStatus.pending,
      isSold: json['isSold'] == true,
    );
  }
}

enum GalleryStatus { verified, pending }
