import 'dart:convert';
import 'dart:typed_data';

import '../api/image_api.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reown_appkit/reown_appkit.dart';

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

    final bytes = await image.readAsBytes();

    setState(() {
      _pickedImage = image;
      _imageBytes = bytes;
    });
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();

    setState(() {
      _pickedImage = image;
      _imageBytes = bytes;
    });
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
                maxLines: 2,
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
                  onPressed: _isRegistering ? null : _registerOnBlockchain,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isRegistering
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Upload & Register on Blockchain',
                          style: TextStyle(
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
