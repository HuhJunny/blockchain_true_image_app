import 'package:flutter/material.dart';

import '../api/user_api.dart';
import '../core/network_image_view.dart';
import 'detailed_image_page.dart';
import 'edit_profile_page.dart';

class UserInfoPage extends StatefulWidget {
  const UserInfoPage({super.key});

  @override
  State<UserInfoPage> createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  late Future<_ProfileData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadProfile();
  }

  Future<_ProfileData> _loadProfile() async {
    final results = await Future.wait([
      UserApi.getMe(),
      UserApi.getMyOrders(0),
      UserApi.getMyFavorites(0),
    ]);
    return _ProfileData(
      user: Map<String, dynamic>.from(results[0] as Map),
      orders: (results[1] as List).map(ProfileImageItem.fromOrder).toList(),
      favorites: (results[2] as List).map(ProfileImageItem.fromImage).toList(),
    );
  }

  void _refresh() {
    setState(() {
      _future = _loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<_ProfileData>(
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
                  child: Text('Failed to load profile: ${snapshot.error}'),
                ),
              ],
            );
          }

          final data = snapshot.data!;
          final name = (data.user['nickname'] ?? data.user['name'] ?? 'User')
              .toString();
          final email = (data.user['email'] ?? '').toString();

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileHeader(name: name, email: email),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final changed = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              EditProfilePage(initialUser: data.user),
                        ),
                      );
                      if (changed == true) _refresh();
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
                  count: data.orders.length,
                ),
                const SizedBox(height: 12),
                _HorizontalImageList(items: data.orders),
                const SizedBox(height: 28),
                _SectionTitle(
                  title: 'Liked Lists',
                  count: data.favorites.length,
                ),
                const SizedBox(height: 12),
                _HorizontalImageList(items: data.favorites),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;

  const _ProfileHeader({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFFE5E7EB),
          child: Icon(Icons.person, color: Colors.black87),
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
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
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

  const _SectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
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

  const _HorizontalImageList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: Text('No items yet.')),
      );
    }

    return SizedBox(
      height: 265,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _ProfileImageCard(item: items[index]),
      ),
    );
  }
}

class _ProfileImageCard extends StatelessWidget {
  final ProfileImageItem item;

  const _ProfileImageCard({required this.item});

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
                imageId: item.imageId,
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
              SizedBox(
                height: 150,
                child: NetworkImageView(
                  path: item.thumbnailUrl,
                  fallback: Container(
                    color: const Color(0xFFF3F4F6),
                    child: const Center(child: Text('Thumbnail')),
                  ),
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
                        item.price,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        item.subtitle,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileImageItem {
  final int imageId;
  final String title;
  final String price;
  final String subtitle;
  final String thumbnailUrl;

  const ProfileImageItem({
    required this.imageId,
    required this.title,
    required this.price,
    required this.subtitle,
    required this.thumbnailUrl,
  });

  factory ProfileImageItem.fromImage(dynamic raw) {
    final json = Map<String, dynamic>.from(raw as Map);
    return ProfileImageItem(
      imageId: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? 'Untitled').toString(),
      price: '\$ ${json['price'] ?? 0}',
      subtitle: (json['verificationStatus'] ?? '').toString(),
      thumbnailUrl: (json['thumbnailUrl'] ?? '').toString(),
    );
  }

  factory ProfileImageItem.fromOrder(dynamic raw) {
    final json = Map<String, dynamic>.from(raw as Map);
    return ProfileImageItem(
      imageId: (json['imageId'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? 'Untitled').toString(),
      price: '\$ ${json['price'] ?? 0}',
      subtitle: (json['purchasedAt'] ?? '').toString(),
      thumbnailUrl: (json['thumbnailUrl'] ?? '').toString(),
    );
  }
}

class _ProfileData {
  final Map<String, dynamic> user;
  final List<ProfileImageItem> orders;
  final List<ProfileImageItem> favorites;

  const _ProfileData({
    required this.user,
    required this.orders,
    required this.favorites,
  });
}
