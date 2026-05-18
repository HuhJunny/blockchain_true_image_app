import 'package:flutter/material.dart';
import 'user_info_page.dart';
import 'upload_page.dart';
import 'my_gallery_page.dart';
import 'gallery_page.dart';
import 'detailed_image_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<ImageItem> _items = const [
    ImageItem(
      title: 'Sunset View',
      description: 'Beautiful sunset',
      category: 'Nature',
      uploadedAt: '2023-10-01',
      isFavorite: true,
      hasDerivative: false,
      verified: true,
    ),
    ImageItem(
      title: 'Forest Adventure',
      description: 'Forest hike',
      category: 'Adventure',
      uploadedAt: '2023-10-01',
      isFavorite: false,
      hasDerivative: false,
      verified: true,
    ),
    ImageItem(
      title: 'City Lights',
      description: 'City skyline',
      category: 'Urban',
      uploadedAt: '2023-10-01',
      isFavorite: true,
      hasDerivative: true,
      verified: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeContent(
        items: _items,
          onOpenUpload: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UploadPage(
                  openCameraOnStart: true,
                ),
              ),
            );
          },
          onOpenGallery: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GalleryPage(), 
              ),
            );
          },
        ),
        const SizedBox.shrink(),
        const MyGalleryPage(),
        const UserInfoPage(),
      ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UploadPage(
                openCameraOnStart: true,
              ),
            ),
          );
          return;
        }

        setState(() => _selectedIndex = index);
      },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.file_upload_outlined),
            selectedIcon: Icon(Icons.file_upload),
            label: 'Upload',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'Gallery',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final List<ImageItem> items;
  final VoidCallback onOpenUpload;
  final VoidCallback onOpenGallery;

  const _HomeContent({
    required this.items,
    required this.onOpenUpload,
    required this.onOpenGallery,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _UserHeader(
            name: 'John Doe',
            email: 'JohnDoe@gmail.com',
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpenUpload,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera & Upload'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const _HeroCarousel(),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Images',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: onOpenGallery,
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 700
                  ? 4
                  : width >= 520
                      ? 3
                      : 2;

              return GridView.builder(
                itemCount: items.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemBuilder: (context, index) {
                  return _ImageCard(item: items[index]);
                },
              );
            },
          ),
        ],
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
          radius: 24,
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
                  fontSize: 17,
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
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none),
        ),
      ],
    );
  }
}

class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel();

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  int _currentPage = 0;

  final List<String> _messages = const [
    'Swipe through your uploaded images.',
    'Check image authenticity records.',
    'Upload photos and register proofs.',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          PageView.builder(
            itemCount: _messages.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.image_search_outlined,
                      size: 52,
                      color: Colors.black87,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _messages[index],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '이미지 등록, 검증, 갤러리 확인을 한 화면에서 시작할 수 있습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _messages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == index ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Colors.black
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  final ImageItem item;

  const _ImageCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
      Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailedImagePage(
          image: ImageDetailInfo.sample(
            title: item.title,
            description: item.description,
            status: item.verified ? 'Verified' : 'Pending',
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
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
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
                    child: _CategoryBadge(text: item.category),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _VerifyBadge(verified: item.verified),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
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
                      'Uploaded on ${item.uploadedAt}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
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
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String text;

  const _CategoryBadge({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _VerifyBadge extends StatelessWidget {
  final bool verified;

  const _VerifyBadge({
    required this.verified,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      verified ? Icons.verified : Icons.pending_outlined,
      size: 20,
      color: verified ? Colors.blue : Colors.orange,
    );
  }
}



class _SimplePage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const _SimplePage({
    required this.title,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: Colors.black87,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImageItem {
  final String title;
  final String description;
  final String category;
  final String uploadedAt;
  final bool isFavorite;
  final bool hasDerivative;
  final bool verified;

  const ImageItem({
    required this.title,
    required this.description,
    required this.category,
    required this.uploadedAt,
    required this.isFavorite,
    required this.hasDerivative,
    required this.verified,
  });
}