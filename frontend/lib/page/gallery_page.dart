import 'package:flutter/material.dart';
import 'detailed_image_page.dart';

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  final List<GallerySection> sections = const [
    GallerySection(
      title: 'Nature',
      items: [
        GalleryItem(
          title: 'Sunset View',
          description: 'Beautiful sunset',
          category: 'Nature',
          uploadedAt: '2023-10-01',
          isFavorite: true,
        ),
        GalleryItem(
          title: 'Forest Adventure',
          description: 'Forest hike',
          category: 'Nature',
          uploadedAt: '2023-10-01',
        ),
        GalleryItem(
          title: 'City Lights',
          description: 'City skyline',
          category: 'Nature',
          uploadedAt: '2023-10-01',
          isFavorite: true,
          hasDerivative: true,
        ),
      ],
    ),
    GallerySection(
      title: 'Adventure',
      items: [
        GalleryItem(
          title: 'Sunset View',
          description: 'Beautiful sunset',
          category: 'Adventure',
          uploadedAt: '2023-10-01',
          isFavorite: true,
        ),
        GalleryItem(
          title: 'Forest Adventure',
          description: 'Forest hike',
          category: 'Adventure',
          uploadedAt: '2023-10-01',
        ),
        GalleryItem(
          title: 'City Lights',
          description: 'City skyline',
          category: 'Adventure',
          uploadedAt: '2023-10-01',
          isFavorite: true,
          hasDerivative: true,
        ),
      ],
    ),
    GallerySection(
      title: 'Urban',
      items: [
        GalleryItem(
          title: 'Sunset View',
          description: 'Beautiful sunset',
          category: 'Adventure',
          uploadedAt: '2023-10-01',
          isFavorite: true,
        ),
        GalleryItem(
          title: 'Forest Adventure',
          description: 'Forest hike',
          category: 'Adventure',
          uploadedAt: '2023-10-01',
        ),
        GalleryItem(
          title: 'City Lights',
          description: 'City skyline',
          category: 'Adventure',
          uploadedAt: '2023-10-01',
          isFavorite: true,
          hasDerivative: true,
        ),
      ],
    ),
  ];

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
        style: TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Gallery',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 24),

            for (final section in sections) ...[
              _GallerySectionView(section: section),
              const SizedBox(height: 28),
            ],
          ],
        ),
      ),
    ),
  );
}
}

class _GallerySectionView extends StatelessWidget {
  final GallerySection section;

  const _GallerySectionView({
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 265,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: section.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _GalleryCard(item: section.items[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final GalleryItem item;

  const _GalleryCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 158,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailedImagePage(
            image: ImageDetailInfo.sample(
              title: item.title,
              description: item.description,
              status: 'Verified',
              category: item.category.toUpperCase(),
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
              SizedBox(
                height: 150,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: const Color(0xFFF3F4F6),
                      child: Center(
                        child: Text(
                          item.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                        ),
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
                          item.category,
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
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Uploaded on ${item.uploadedAt}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),

                      Row(
                        children: [
                          if (item.isFavorite)
                            const Icon(
                              Icons.favorite,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                          if (item.isFavorite && item.hasDerivative)
                            const SizedBox(width: 8),
                          if (item.hasDerivative)
                            const Icon(
                              Icons.account_tree_outlined,
                              size: 18,
                              color: Colors.black87,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GallerySection {
  final String title;
  final List<GalleryItem> items;

  const GallerySection({
    required this.title,
    required this.items,
  });
}

class GalleryItem {
  final String title;
  final String description;
  final String category;
  final String uploadedAt;
  final bool isFavorite;
  final bool hasDerivative;

  const GalleryItem({
    required this.title,
    required this.description,
    required this.category,
    required this.uploadedAt,
    this.isFavorite = false,
    this.hasDerivative = false,
  });
}