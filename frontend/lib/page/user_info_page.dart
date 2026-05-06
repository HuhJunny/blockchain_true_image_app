import 'package:flutter/material.dart';
import 'edit_profile_page.dart';
import 'detailed_image_page.dart';

class UserInfoPage extends StatelessWidget {
  const UserInfoPage({super.key});

  final List<ProfileImageItem> purchaseHistory = const [
    ProfileImageItem(
      title: 'Sunset View',
      description: 'Beautiful sunset',
      category: 'Nature',
      uploadedAt: '2023-10-01',
      liked: false,
    ),
    ProfileImageItem(
      title: 'Forest Adventure',
      description: 'Forest hike',
      category: 'Adventure',
      uploadedAt: '2023-10-01',
      liked: false,
    ),
    ProfileImageItem(
      title: 'City Lights',
      description: 'City skyline',
      category: 'Urban',
      uploadedAt: '2023-10-01',
      liked: false,
    ),
  ];

  final List<ProfileImageItem> likedList = const [
    ProfileImageItem(
      title: 'Sunset View',
      description: 'Beautiful sunset',
      category: 'Nature',
      uploadedAt: '2023-10-01',
      liked: true,
    ),
    ProfileImageItem(
      title: 'Forest Adventure',
      description: 'Forest hike',
      category: 'Adventure',
      uploadedAt: '2023-10-01',
      liked: true,
    ),
    ProfileImageItem(
      title: 'City Lights',
      description: 'City skyline',
      category: 'Urban',
      uploadedAt: '2023-10-01',
      liked: true,
      hasDerivative: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProfileHeader(
            name: 'John Doe',
            email: 'JohnDoe@gmail.com',
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfilePage(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Edit Profile',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),
          _SectionTitle(
            title: 'Purchase History',
            count: purchaseHistory.length,
          ),
          const SizedBox(height: 12),
          _HorizontalImageList(items: purchaseHistory),

          const SizedBox(height: 28),
          _SectionTitle(
            title: 'Liked Lists',
            count: likedList.length,
          ),
          const SizedBox(height: 12),
          _HorizontalImageList(items: likedList),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;

  const _ProfileHeader({
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
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const _SectionTitle({
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: const TextStyle(
            color: Colors.black45,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HorizontalImageList extends StatelessWidget {
  final List<ProfileImageItem> items;

  const _HorizontalImageList({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 265,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _ProfileImageCard(item: items[index]);
        },
      ),
    );
  }
}

class _ProfileImageCard extends StatelessWidget {
  final ProfileImageItem item;

  const _ProfileImageCard({
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
                      const Spacer(),
                      Row(
                        children: [
                          if (item.liked)
                            const Icon(
                              Icons.favorite,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                          if (item.liked && item.hasDerivative)
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

class ProfileImageItem {
  final String title;
  final String description;
  final String category;
  final String uploadedAt;
  final bool liked;
  final bool hasDerivative;

  const ProfileImageItem({
    required this.title,
    required this.description,
    required this.category,
    required this.uploadedAt,
    required this.liked,
    this.hasDerivative = false,
  });
}