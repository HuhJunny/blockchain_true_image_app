import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../api/api_client.dart';
import '../api/image_api.dart';
import '../core/token_storage.dart';

class UploadPage extends StatefulWidget {
  final bool openCameraOnStart;
  final ReownAppKitModal? appKitModal;

  const UploadPage({
    super.key,
    this.openCameraOnStart = false,
    this.appKitModal,
  });

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  static const String _sepoliaChain = 'eip155:11155111';
  static const String _contractAddress =
      '0x6154ab54f64106e00C715EBfC7cE6ce8C5dfF9CB';

  final ImagePicker _picker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  Uint8List? _imageBytes;
  XFile? _pickedImage;
  bool _isRegistering = false;
  bool _isPreVerifying = false;
  String? _preVerifyStatus;
  String? _preVerifyMessage;

  bool get _isDuplicateSelectedImage =>
      _preVerifyStatus == 'MATCHED' || _preVerifyStatus == 'MATCHED_WATERMARK';

  bool get _canUploadSelectedImage => _preVerifyStatus == 'NOT_MATCHED';

  String _selectedCategory = 'LANDSCAPE';
  final String _deviceId = 'device-abc-123';
  late final String _capturedAt;

  @override
  void initState() {
    super.initState();

    _capturedAt = DateTime.now().toUtc().toIso8601String();

    if (widget.openCameraOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _takePhoto();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (image == null) return;

    await _setPickedImageAndVerify(image);
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;

    await _setPickedImageAndVerify(image);
  }

  Future<void> _setPickedImageAndVerify(XFile image) async {
    final bytes = await image.readAsBytes();

    if (!mounted) return;

    setState(() {
      _pickedImage = image;
      _imageBytes = bytes;
      _preVerifyStatus = null;
      _preVerifyMessage = '이미지 검증 중...';
      _isPreVerifying = true;
    });

    await _verifyImageBeforeUpload(image);
  }

  String _buildPreUploadVerifyMessage(String status, int? imageId) {
    switch (status) {
      case 'MATCHED':
        return imageId == null
            ? '이미 등록된 원본 이미지와 일치합니다. 중복 업로드할 수 없습니다.'
            : '이미 등록된 원본 이미지와 일치합니다. Image ID: $imageId';
      case 'MATCHED_WATERMARK':
        return imageId == null
            ? '플랫폼에서 발급한 워터마크 이미지와 일치합니다. 업로드할 수 없습니다.'
            : '플랫폼에서 발급한 워터마크 이미지와 일치합니다. Image ID: $imageId';
      case 'NOT_MATCHED':
        return '신규 이미지로 확인되었습니다. 업로드를 진행할 수 있습니다.';
      default:
        return '이미지 검증 결과를 확인할 수 없습니다.';
    }
  }

  Future<void> _verifyImageBeforeUpload(XFile image) async {
    try {
      final accessToken = await TokenStorage.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('로그인이 필요합니다. 먼저 지갑으로 로그인해주세요.');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiClient.baseUrl}/verification/check'),
      );

      request.headers['Authorization'] = 'Bearer $accessToken';

      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('서버 검증 실패: ${response.statusCode} ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final status = (data['verificationStatus'] ?? data['status'] ?? 'UNKNOWN')
          .toString()
          .toUpperCase();

      final rawImageId = data['imageId'];
      final int? imageId = rawImageId is num
          ? rawImageId.toInt()
          : int.tryParse(rawImageId?.toString() ?? '');

      final imageHash =
          (data['imageHash'] ?? data['contentHash'] ?? data['hash'] ?? '')
              .toString();

      final reason = (data['reason'] ?? data['message'] ?? '').toString();

      if (!mounted) return;

      setState(() {
        _preVerifyStatus = status;
        _preVerifyMessage = _buildPreUploadVerifyMessage(status, imageId);
      });

      _showPreUploadVerifyResultDialog(
        verificationStatus: status,
        imageId: imageId,
        imageHash: imageHash.isEmpty ? '응답에 imageHash가 없습니다.' : imageHash,
        reason: reason.isEmpty ? null : reason,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _preVerifyStatus = 'ERROR';
        _preVerifyMessage = '이미지 검증 실패: $e';
      });

      _showPreUploadVerifyResultDialog(
        verificationStatus: 'ERROR',
        imageHash: '검증 실패로 해시를 확인할 수 없습니다.',
        reason: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPreVerifying = false;
        });
      }
    }
  }

  void _showPreUploadVerifyResultDialog({
    required String verificationStatus,
    required String imageHash,
    int? imageId,
    String? reason,
  }) {
    String titleText;
    String descriptionText;
    IconData icon;
    Color iconColor;

    switch (verificationStatus) {
      case 'MATCHED':
        titleText = '원본 이미지 검증 성공';
        descriptionText =
            '선택한 이미지의 SHA-256 해시가 이미 등록된 원본 이미지와 일치합니다. 중복 업로드할 수 없습니다.';
        icon = Icons.warning_amber_rounded;
        iconColor = Colors.orange;
        break;
      case 'MATCHED_WATERMARK':
        titleText = '워터마크 이미지 검증 성공';
        descriptionText = '선택한 이미지가 플랫폼에서 발급한 워터마크 이미지와 일치합니다. 업로드할 수 없습니다.';
        icon = Icons.warning_amber_rounded;
        iconColor = Colors.orange;
        break;
      case 'NOT_MATCHED':
        titleText = '신규 이미지 확인';
        descriptionText = '등록된 원본 또는 워터마크 이미지와 일치하지 않습니다. 업로드를 진행할 수 있습니다.';
        icon = Icons.check_circle_rounded;
        iconColor = Colors.blue;
        break;
      case 'ERROR':
        titleText = '이미지 검증 실패';
        descriptionText = reason ?? '이미지 검증 중 오류가 발생했습니다.';
        icon = Icons.error_outline_rounded;
        iconColor = Colors.orange;
        break;
      default:
        titleText = '검증 결과 확인 필요';
        descriptionText = reason ?? '서버 검증 결과를 확인할 수 없습니다.';
        icon = Icons.info_outline_rounded;
        iconColor = Colors.orange;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: iconColor, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          titleText,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    descriptionText,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF555555),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Verification Result',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _VerifyInfoRow(
                          label: 'Status',
                          value: verificationStatus,
                        ),
                        if (imageId != null)
                          _VerifyInfoRow(
                            label: 'Image ID',
                            value: imageId.toString(),
                          ),
                        _VerifyInfoRow(
                          label: 'SHA-256',
                          value: imageHash,
                          selectable: true,
                        ),
                        if (reason != null && reason.isNotEmpty)
                          _VerifyInfoRow(label: 'Reason', value: reason),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('확인'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showImageSelectSheet() {
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
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('카메라로 촬영'),
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('갤러리에서 선택'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromGallery();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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

  String _friendlyError(Object error) {
    if (error is ReownAppKitModalException) {
      return error.message.toString();
    }
    return error.toString();
  }

  BigInt _registrationPrice() {
    final rawPrice = _priceController.text.trim();
    if (rawPrice.isEmpty) {
      return BigInt.one;
    }

    final price = BigInt.tryParse(rawPrice);
    if (price == null || price <= BigInt.zero) {
      throw Exception('Price must be a positive integer.');
    }

    return price;
  }

  String _imageRegistrationHash() {
    final bytes = _imageBytes;
    if (bytes == null) {
      throw Exception('Image bytes are not ready.');
    }
    return '0x${sha256.convert(bytes)}';
  }

  String _buildRegisterImageCalldata(String pHash, BigInt price) {
    const selector = '0x8f91ad9d';
    final hashHex = hex.encode(utf8.encode(pHash));
    final paddedHashLength = ((hashHex.length + 63) ~/ 64) * 64;

    final offset = BigInt.from(64).toRadixString(16).padLeft(64, '0');
    final priceHex = price.toRadixString(16).padLeft(64, '0');
    final hashLength = (hashHex.length ~/ 2).toRadixString(16).padLeft(64, '0');
    final hashEncoded = hashHex.padRight(paddedHashLength, '0');

    return selector + offset + priceHex + hashLength + hashEncoded;
  }

  void _debugSession(String label, ReownAppKitModal modal) {
    final approvedChains = modal.session?.getApprovedChains() ?? const [];
    final approvedEip155Chains = approvedChains
        .where((chain) => chain.startsWith('eip155:'))
        .toList();
    debugPrint('[$label] isConnected=${modal.isConnected}');
    debugPrint('[$label] selectedChain=${modal.selectedChain?.chainId}');
    debugPrint('[$label] topic=${modal.session?.topic}');
    debugPrint('[$label] namespaces=${modal.session?.namespaces}');
    debugPrint('[$label] eip155Accounts=${_eip155Accounts(modal)}');
    debugPrint('[$label] approvedEip155Chains=$approvedEip155Chains');
  }

  void _assertSepoliaApproved(ReownAppKitModal modal) {
    final approvedChains = modal.session?.getApprovedChains() ?? const [];
    final approvedEip155Chains = approvedChains
        .where((chain) => chain.startsWith('eip155:'))
        .toList();
    if (!approvedEip155Chains.contains(_sepoliaChain)) {
      throw Exception(
        '현재 WalletConnect 세션이 Sepolia($_sepoliaChain)를 승인하지 않았습니다. '
        '로그인 화면에서 연결 해제 후 MetaMask를 다시 연결해야 합니다. '
        '현재 승인된 체인: $approvedChains',
      );
    }
  }

  Future<void> _registerOnBlockchain() async {
    if (_pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take or select an image first.')),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an image title.')),
      );
      return;
    }

    if (_isPreVerifying) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미지 검증이 끝난 뒤 업로드해주세요.')));
      return;
    }

    if (_preVerifyStatus == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미지 검증이 완료된 뒤 업로드해주세요.')));
      return;
    }

    if (_isDuplicateSelectedImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 등록된 이미지와 일치하여 업로드할 수 없습니다.')),
      );
      return;
    }

    if (!_canUploadSelectedImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 검증이 완료된 신규 이미지만 업로드할 수 있습니다.')),
      );
      return;
    }

    if (_isRegistering) return;

    final uploadData = {
      'imageName': _pickedImage!.name,
      'imageTitle': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'price': _priceController.text.trim(),
      'category': _selectedCategory,
      'deviceId': _deviceId,
      'capturedAt': _capturedAt,
    };
    debugPrint('[UploadPage] uploadData=$uploadData');

    setState(() {
      _isRegistering = true;
    });

    try {
      final modal = _appKitModal;
      if (!modal.isConnected || modal.session == null) {
        throw Exception(
          'MetaMask is not connected. Return to Wallet Login and connect first.',
        );
      }

      await _ensureSepolia(modal);
      _debugSession('UploadPage.beforeRegister', modal);
      _assertSepoliaApproved(modal);

      final from = _walletAddress(modal);
      final pHash = _imageRegistrationHash();
      final price = _registrationPrice();
      final data = _buildRegisterImageCalldata(pHash, price);

      debugPrint('[UploadPage] from=$from');
      debugPrint('[UploadPage] to=$_contractAddress');
      debugPrint('[UploadPage] chainId=$_sepoliaChain');
      debugPrint('[UploadPage] pHash=$pHash');
      debugPrint('[UploadPage] price=$price');
      debugPrint('[UploadPage] calldata=$data');

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
              'value': '0x0',
            },
          ],
        ),
      );

      debugPrint('[UploadPage] txHash=$result');

      final imageHash = _imageRegistrationHash();
      final txHash = result.toString();
      await ImageApi.upload(
        fileName: _pickedImage!.name,
        bytes: _imageBytes!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: _priceController.text.trim().isEmpty
            ? '1'
            : _priceController.text.trim(),
        category: _selectedCategory,
        deviceId: _deviceId,
        capturedAt: _capturedAt,
        imageHash: imageHash,
        txHash: txHash,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Upload completed.')));
      Navigator.pop(context, true);
    } catch (e, stackTrace) {
      debugPrint('[UploadPage] register failed: $e');
      debugPrint('[UploadPage] stackTrace: $stackTrace');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Blockchain registration failed: ${_friendlyError(e)}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
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
          'Upload',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _UserHeader(name: 'John Doe', email: 'JohnDoe@gmail.com'),

              const SizedBox(height: 20),

              GestureDetector(
                onTap: _showImageSelectSheet,
                child: Container(
                  width: double.infinity,
                  height: 238,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: _imageBytes == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 48,
                              color: Colors.black54,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Tap to select an image',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Camera / Gallery upload',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : Image.memory(
                          _imageBytes!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              if (_preVerifyMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      if (_isPreVerifying)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          _preVerifyStatus == 'NOT_MATCHED'
                              ? Icons.check_circle_outline
                              : _isDuplicateSelectedImage
                              ? Icons.warning_amber_rounded
                              : Icons.info_outline_rounded,
                          size: 21,
                          color: _preVerifyStatus == 'NOT_MATCHED'
                              ? Colors.blue
                              : _isDuplicateSelectedImage
                              ? Colors.orange
                              : Colors.black54,
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _preVerifyMessage!,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              _InputField(
                label: 'Image Title',
                hintText: 'Enter Image Title',
                controller: _titleController,
              ),

              const SizedBox(height: 18),

              _InputField(
                label: 'Description',
                hintText: 'Write a short description',
                controller: _descriptionController,
                maxLines: 1,
              ),

              const SizedBox(height: 18),

              _InputField(
                label: 'Price',
                hintText: 'Write a price',
                controller: _priceController,
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 22),

              const Text(
                'Category',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 10),

              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _CategoryChip(
                    label: 'LANDSCAPE',
                    selected: _selectedCategory == 'LANDSCAPE',
                    onTap: () {
                      setState(() {
                        _selectedCategory = 'LANDSCAPE';
                      });
                    },
                  ),
                  _CategoryChip(
                    label: 'PORTRAIT',
                    selected: _selectedCategory == 'PORTRAIT',
                    onTap: () {
                      setState(() {
                        _selectedCategory = 'PORTRAIT';
                      });
                    },
                  ),
                  _CategoryChip(
                    label: 'URBAN',
                    selected: _selectedCategory == 'URBAN',
                    onTap: () {
                      setState(() {
                        _selectedCategory = 'URBAN';
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _ReadOnlyField(label: 'Device ID', value: _deviceId),

              const SizedBox(height: 18),

              _ReadOnlyField(label: 'Captured At', value: _capturedAt),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      (_isRegistering ||
                          _isPreVerifying ||
                          _pickedImage == null ||
                          !_canUploadSelectedImage)
                      ? null
                      : _registerOnBlockchain,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: (_isRegistering || _isPreVerifying)
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isPreVerifying ? '이미지 검증 중...' : 'Uploading...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _pickedImage == null
                              ? '이미지를 선택해주세요'
                              : _isDuplicateSelectedImage
                              ? '이미 등록된 이미지'
                              : _preVerifyStatus == 'ERROR'
                              ? '이미지 검증 실패'
                              : _preVerifyStatus == 'UNKNOWN'
                              ? '검증 결과 확인 필요'
                              : 'Upload & Register on Blockchain',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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

class _UserHeader extends StatelessWidget {
  final String name;
  final String email;

  const _UserHeader({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 22,
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
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VerifyInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool selectable;

  const _VerifyInfoRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueWidget = selectable
        ? SelectableText(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.black,
              height: 1.35,
            ),
          )
        : Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF777777),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;

  const _InputField({
    required this.label,
    required this.hintText,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFF928B8B), fontSize: 16),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE6E6E6)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE6E6E6))),
          ),
          child: Text(
            value,
            style: const TextStyle(color: Color(0xFF928B8B), fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.black,
      backgroundColor: const Color(0xFFE6E6E6),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF928B8B),
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(99),
        side: BorderSide(
          color: selected ? Colors.black : const Color(0xFF868686),
        ),
      ),
    );
  }
}
