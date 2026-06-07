import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reown_appkit/reown_appkit.dart';
import '../services/image_hash_service.dart';

import '../api/image_api.dart';
import '../api/user_api.dart';
import '../core/network_image_view.dart';
import 'detailed_image_page.dart';
import 'gallery_page.dart';
import 'my_gallery_page.dart';
import 'upload_page.dart';
import 'user_info_page.dart';

class HomePage extends StatefulWidget {
  final ReownAppKitModal? appKitModal;

  const HomePage({super.key, this.appKitModal});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late Future<_HomeData> _homeFuture;

  bool _isHashVerifying = false;
  String? _lastVerifyMessage;

  final ImagePicker _picker = ImagePicker();

  // 실제 휴대폰에서 테스트 중이면 localhost 말고 PC IPv4 주소로 변경
  // 예: http://192.168.0.15:8080
  static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:4000',
);

  @override
  void initState() {
    super.initState();
    _homeFuture = _loadHome();
  }

  Future<_HomeData> _loadHome() async {
    final results = await Future.wait([
      UserApi.getMe().catchError((_) => <String, dynamic>{}),
      ImageApi.getImages(0, size: 6),
    ]);

    final user = Map<String, dynamic>.from(results[0] as Map);
    final rawItems = (results[1] as List).cast<dynamic>();

    return _HomeData(
      name: (user['nickname'] ?? user['name'] ?? 'Guest').toString(),
      email: (user['email'] ?? '').toString(),
      items: rawItems.map(ImageItem.fromJson).toList(),
    );
  }

  void _refreshHome() {
    setState(() {
      _homeFuture = _loadHome();
    });
  }

  Future<void> _captureAndVerifyImageHash() async {
  if (_isHashVerifying) return;

  setState(() {
    _isHashVerifying = true;
    _lastVerifyMessage = null;
  });

  try {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
    );

    if (image == null) {
      setState(() {
        _lastVerifyMessage = '사진 촬영이 취소되었습니다.';
      });
      return;
    }

    setState(() {
      _lastVerifyMessage = '이미지 해시를 생성 중...';
    });

    final hashes = await ImageHashService.calculate(image.path);

    debugPrint('[ImageHash] SHA-256: ${hashes.sha256Hash}');
    debugPrint('[ImageHash] pHash: ${hashes.pHash}');

    setState(() {
      _lastVerifyMessage = '이미지 파일과 해시 정보를 서버에서 검증 중...';
    });

    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('로그인이 필요합니다. 먼저 지갑으로 로그인해주세요.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/verification/check'),
    );

    request.headers['Authorization'] = 'Bearer $accessToken';

    request.fields['sha256Hash'] = hashes.sha256Hash;
    request.fields['pHash'] = hashes.pHash;

    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        image.path,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('서버 검증 실패: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final bool isVerified = data['isVerified'] == true;
    final String verificationStatus =
        data['verificationStatus']?.toString() ?? 'UNKNOWN';

    final String? imageHash = data['imageHash']?.toString();
    final String sha256Hash =
        data['sha256Hash']?.toString() ?? hashes.sha256Hash;
    final String pHash = data['pHash']?.toString() ?? hashes.pHash;

    final String? matchType = data['matchType']?.toString();
    final String? txHash = data['txHash']?.toString();
    final String? reason = data['reason']?.toString();

    final int? imageId =
        data['imageId'] is int ? data['imageId'] as int : null;

    final int? hammingDistance = data['hammingDistance'] is int
        ? data['hammingDistance'] as int
        : null;

    final double? similarity = data['similarity'] is num
        ? (data['similarity'] as num).toDouble()
        : null;

    setState(() {
      if (isVerified) {
        if (matchType == 'EXACT') {
          _lastVerifyMessage = '검증 성공: SHA-256 기준으로 완전히 동일한 이미지입니다.';
        } else if (matchType == 'SIMILAR') {
          _lastVerifyMessage = '검증 성공: pHash 기준으로 유사한 이미지입니다.';
        } else {
          _lastVerifyMessage = '검증 성공: 등록된 이미지와 일치합니다.';
        }
      } else {
        _lastVerifyMessage =
            '검증 실패: ${reason ?? '등록된 이미지와 동일하거나 유사하지 않습니다.'}';
      }
    });

    if (!mounted) return;

    _showHashVerifyResultDialog(
      imageHash: imageHash,
      sha256Hash: sha256Hash,
      pHash: pHash,
      isVerified: isVerified,
      verificationStatus: verificationStatus,
      matchType: matchType,
      imageId: imageId,
      txHash: txHash,
      reason: reason,
      hammingDistance: hammingDistance,
      similarity: similarity,
    );
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _lastVerifyMessage = '검증 실패: $e';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('검증 실패: $e')),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isHashVerifying = false;
      });
    }
  }
}

  void _showHashVerifyResultDialog({
  String? imageHash,
  required String sha256Hash,
  required String pHash,
  required bool isVerified,
  required String verificationStatus,
  String? matchType,
  int? imageId,
  String? txHash,
  String? reason,
  int? hammingDistance,
  double? similarity,
}) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(
              isVerified ? Icons.verified : Icons.warning_amber_rounded,
              color: isVerified ? Colors.blue : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(isVerified ? '검증 성공' : '검증 실패'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isVerified
                    ? _buildVerifySuccessMessage(matchType)
                    : reason ?? '등록된 이미지와 동일하거나 유사하지 않습니다.',
              ),

              const SizedBox(height: 16),

              const Text(
                'Verification Status',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SelectableText(verificationStatus),

              if (matchType != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Match Type',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                SelectableText(matchType),
              ],

              if (imageId != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Matched Image ID',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                SelectableText(imageId.toString()),
              ],

              const SizedBox(height: 12),
              const Text(
                'SHA-256 Hash',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SelectableText(
                sha256Hash,
                style: const TextStyle(fontSize: 12),
              ),

              const SizedBox(height: 12),
              const Text(
                'pHash',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SelectableText(
                pHash,
                style: const TextStyle(fontSize: 12),
              ),

              if (imageHash != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Server Image Hash',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  imageHash,
                  style: const TextStyle(fontSize: 12),
                ),
              ],

              if (hammingDistance != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Hamming Distance',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                SelectableText(hammingDistance.toString()),
              ],

              if (similarity != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Similarity',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                SelectableText(similarity.toStringAsFixed(3)),
              ],

              if (txHash != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Transaction Hash',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  txHash,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      );
    },
  );
}
String _buildVerifySuccessMessage(String? matchType) {
  if (matchType == 'EXACT') {
    return 'SHA-256 기준으로 기존 이미지와 완전히 동일합니다.';
  }

  if (matchType == 'SIMILAR') {
    return 'SHA-256은 다르지만 pHash 기준으로 기존 이미지와 유사합니다.';
  }

  return '서버 검증 결과, 등록된 이미지와 일치합니다.';
}

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeContent(
        homeFuture: _homeFuture,
        onRefresh: _refreshHome,
        isHashVerifying: _isHashVerifying,
        lastVerifyMessage: _lastVerifyMessage,
        onVerifyByHash: _captureAndVerifyImageHash,
        onOpenUpload: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UploadPage(
                openCameraOnStart: true,
                appKitModal: widget.appKitModal,
              ),
            ),
          ).then((changed) {
            if (changed == true) _refreshHome();
          });
        },
        onOpenGallery: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GalleryPage()),
          );
        },
      ),
      const SizedBox.shrink(),
      const MyGalleryPage(),
      const UserInfoPage(),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UploadPage(
                  openCameraOnStart: true,
                  appKitModal: widget.appKitModal,
                ),
              ),
            ).then((changed) {
              if (changed == true) _refreshHome();
            });
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
  final Future<_HomeData> homeFuture;
  final VoidCallback onRefresh;
  final VoidCallback onOpenUpload;
  final VoidCallback onOpenGallery;
  final VoidCallback onVerifyByHash;
  final bool isHashVerifying;
  final String? lastVerifyMessage;

  const _HomeContent({
    required this.homeFuture,
    required this.onRefresh,
    required this.onOpenUpload,
    required this.onOpenGallery,
    required this.onVerifyByHash,
    required this.isHashVerifying,
    required this.lastVerifyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: FutureBuilder<_HomeData>(
        future: homeFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final items = data?.items ?? const <ImageItem>[];

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UserHeader(
                  name: data?.name ?? 'Loading...',
                  email: data?.email ?? '',
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isHashVerifying ? null : onVerifyByHash,
                    icon: isHashVerifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_user_outlined),
                    label: Text(
                      isHashVerifying ? '이미지 검증 중...' : '사진 찍어서 이미지 검증',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: Colors.black87,
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (lastVerifyMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      lastVerifyMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
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
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (snapshot.hasError)
                  Center(
                    child: TextButton(
                      onPressed: onRefresh,
                      child: const Text('Failed to load images. Tap to retry.'),
                    ),
                  )
                else if (items.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No images yet.'),
                    ),
                  )
                else
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
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
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
        },
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  final String name;
  final String email;

  const _UserHeader({required this.name, required this.email});

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
                style: const TextStyle(color: Colors.black54, fontSize: 13),
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
                      style: TextStyle(color: Colors.black54, fontSize: 13),
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

  const _ImageCard({required this.item});

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

  const _CategoryBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _VerifyBadge extends StatelessWidget {
  final bool verified;

  const _VerifyBadge({required this.verified});

  @override
  Widget build(BuildContext context) {
    return Icon(
      verified ? Icons.verified : Icons.pending_outlined,
      size: 20,
      color: verified ? Colors.blue : Colors.orange,
    );
  }
}

class ImageItem {
  final int id;
  final String title;
  final String description;
  final String category;
  final String uploadedAt;
  final String thumbnailUrl;
  final bool isFavorite;
  final bool hasDerivative;
  final bool verified;

  const ImageItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.uploadedAt,
    required this.thumbnailUrl,
    required this.isFavorite,
    required this.hasDerivative,
    required this.verified,
  });

  factory ImageItem.fromJson(dynamic raw) {
    final json = Map<String, dynamic>.from(raw as Map);
    final status = (json['verificationStatus'] ?? '').toString().toUpperCase();

    return ImageItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? 'Untitled').toString(),
      description: (json['price'] == null) ? '' : '\$ ${json['price']}',
      category: status.isEmpty ? 'IMAGE' : status,
      uploadedAt: (json['createdAt'] ?? json['uploadedAt'] ?? '').toString(),
      thumbnailUrl: (json['thumbnailUrl'] ?? '').toString(),
      isFavorite: false,
      hasDerivative: false,
      verified: status == 'VERIFIED' || status == 'MATCHED',
    );
  }
}

class _HomeData {
  final String name;
  final String email;
  final List<ImageItem> items;

  const _HomeData({
    required this.name,
    required this.email,
    required this.items,
  });
}
