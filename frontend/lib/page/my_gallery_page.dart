import 'package:flutter/material.dart';
import 'detailed_image_page.dart';

class MyGalleryPage extends StatefulWidget {
  const MyGalleryPage({super.key});

  @override
  State<MyGalleryPage> createState() => _MyGalleryPageState();
}

class _MyGalleryPageState extends State<MyGalleryPage> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'ALL';
  String _searchText = '';

  final List<MyGalleryItem> _items = const [
    MyGalleryItem(
      title: '한강 야경',
      price: 50,
      uploadedAt: '2026-03-29',
      status: GalleryStatus.verified,
      isSold: false,
    ),
    MyGalleryItem(
      title: '도심 거리',
      price: 30,
      uploadedAt: '2026-03-28',
      status: GalleryStatus.verified,
      isSold: true,
    ),
    MyGalleryItem(
      title: '노을 풍경',
      price: 70,
      uploadedAt: '2026-03-27',
      status: GalleryStatus.pending,
      isSold: false,
    ),
    MyGalleryItem(
      title: '한적한 골목',
      price: 40,
      uploadedAt: '2026-03-26',
      status: GalleryStatus.pending,
      isSold: false,
    ),
    MyGalleryItem(
      title: '노을 풍경',
      price: 70,
      uploadedAt: '2026-03-27',
      status: GalleryStatus.pending,
      isSold: false,
    ),
    MyGalleryItem(
      title: '한적한 골목',
      price: 40,
      uploadedAt: '2026-03-26',
      status: GalleryStatus.pending,
      isSold: false,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MyGalleryItem> get _filteredItems {
    return _items.where((item) {
      final matchesSearch = item.title.contains(_searchText);

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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(18),
        ),
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
                _FilterTile(
                  title: 'ALL',
                  selected: _selectedFilter == 'ALL',
                  onTap: () => _selectFilter('ALL'),
                ),
                _FilterTile(
                  title: 'VERIFIED',
                  selected: _selectedFilter == 'VERIFIED',
                  onTap: () => _selectFilter('VERIFIED'),
                ),
                _FilterTile(
                  title: 'PENDING',
                  selected: _selectedFilter == 'PENDING',
                  onTap: () => _selectFilter('PENDING'),
                ),
                _FilterTile(
                  title: 'SOLD',
                  selected: _selectedFilter == 'SOLD',
                  onTap: () => _selectFilter('SOLD'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _UserHeader(
              name: 'John Doe',
              email: 'JohnDoe@gmail.com',
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
                        setState(() {
                          _searchText = value.trim();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search my uploads',
                        hintStyle: const TextStyle(
                          color: Colors.black45,
                          fontSize: 15,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.black45,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFA7A7A7),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Colors.black,
                            width: 1.2,
                          ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Filter',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (_selectedFilter != 'ALL')
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'Filter: $_selectedFilter',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: Text(
                    '검색 결과가 없습니다.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                    ),
                  ),
                ),
              )
            else
              GridView.builder(
                itemCount: items.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.73,
                ),
                itemBuilder: (context, index) {
                  return _MyGalleryCard(item: items[index]);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  final String name;
  final String email;

  const _UserHeader({
    required this.name,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 22,
          backgroundColor: Color(0xFFE5E7EB),
          child: Icon(
            Icons.person,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MyGalleryCard extends StatelessWidget {
  final MyGalleryItem item;

  const _MyGalleryCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final statusText =
        item.status == GalleryStatus.verified ? 'VERIFIED' : 'PENDING';

    final statusColor =
        item.status == GalleryStatus.verified ? Colors.black : Colors.black54;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailedImagePage(
              image: ImageDetailInfo.sample(
                title: item.title,
                price: '\$ ${item.price}',
                status: item.status == GalleryStatus.verified
                  ? 'Verified'
                  : 'Pending',
                category: 'LANDSCAPE',
                timestamp: '${item.uploadedAt}T14:31:10Z',
              ),
            ),
          ),
        );
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFFE5E7EB),
          ),
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
                  Container(
                    color: const Color(0xFFF3F4F6),
                    child: const Center(
                      child: Text(
                        'Thumbnail',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                        ),
                      ),
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
                        style: TextStyle(
                          color: statusColor,
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
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$ ${item.price}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Uploaded on ${item.uploadedAt}',
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

class _FilterTile extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _FilterTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: selected
          ? const Icon(
              Icons.check,
              color: Colors.black,
            )
          : null,
      onTap: onTap,
    );
  }
}

class MyGalleryItem {
  final String title;
  final int price;
  final String uploadedAt;
  final GalleryStatus status;
  final bool isSold;

  const MyGalleryItem({
    required this.title,
    required this.price,
    required this.uploadedAt,
    required this.status,
    required this.isSold,
  });
}

enum GalleryStatus {
  verified,
  pending,
}