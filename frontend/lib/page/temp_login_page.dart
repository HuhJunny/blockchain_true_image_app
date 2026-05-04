import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class TempLoginPage extends StatefulWidget {
  const TempLoginPage({super.key});

  @override
  State<TempLoginPage> createState() => _TempLoginPageState();
}

class _TempLoginPageState extends State<TempLoginPage> {
  ReownAppKitModal? appKitModal;

  bool isInitializing = true;
  bool isLoading = false;

  String? walletAddress;
  String? statusMessage;

  // TODO: 백엔드 주소에 맞게 수정
  // Android 에뮬레이터에서 로컬 서버면 http://10.0.2.2:8080
  // Chrome에서 로컬 서버면 http://localhost:8080
  static const String baseUrl = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    initReown();
  }

  Future<void> initReown() async {
    try {
      const projectId = String.fromEnvironment('REOWN_PROJECT_ID');

      if (projectId.isEmpty) {
        throw Exception(
          'REOWN_PROJECT_ID가 없습니다. 실행 시 --dart-define=REOWN_PROJECT_ID=... 를 넣어주세요.',
        );
      }

      final modal = ReownAppKitModal(
        context: context,
        projectId: projectId,
        metadata: const PairingMetadata(
          name: 'ImageChain Market',
          description: 'Blockchain image verification market',
          url: 'https://imagechain.example.com',
          icons: ['https://imagechain.example.com/icon.png'],
          redirect: Redirect(
            native: 'imagechain://',
          ),
        ),
      );

      await modal.init();

      if (!mounted) return;

      setState(() {
        appKitModal = modal;
        isInitializing = false;
        statusMessage = 'Reown 초기화 완료';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isInitializing = false;
        statusMessage = 'Reown 초기화 실패: $e';
      });
    }
  }

  bool get isConnected {
    return appKitModal?.isConnected == true;
  }

  String get selectedChainId {
    return appKitModal!.selectedChain!.chainId;
  }

  int get chainId {
    return int.parse(selectedChainId.split(':').last);
  }

  String get currentWalletAddress {
    final namespace =
        ReownAppKitModalNetworks.getNamespaceForChainId(selectedChainId);

    return appKitModal!.session!.getAddress(namespace)!;
  }

  Future<void> connectWallet() async {
    if (appKitModal == null) {
      setState(() {
        statusMessage = '아직 Reown 초기화가 끝나지 않았습니다.';
      });
      return;
    }

    try {
      appKitModal!.openModalView();

      setState(() {
        statusMessage = 'MetaMask 연결 화면을 열었습니다.';
      });
    } catch (e) {
      setState(() {
        statusMessage = '지갑 연결 실패: $e';
      });
    }
  }

  Future<void> refreshWalletState() async {
    if (!isConnected) {
      setState(() {
        statusMessage = '아직 지갑이 연결되지 않았습니다.';
      });
      return;
    }

    setState(() {
      walletAddress = currentWalletAddress;
      statusMessage = '지갑 연결 완료: $walletAddress';
    });
  }

  Future<String> signMessage(String message) async {
    if (!isConnected) {
      throw Exception('지갑이 연결되어 있지 않습니다.');
    }

    final namespace =
        ReownAppKitModalNetworks.getNamespaceForChainId(selectedChainId);

    final address = appKitModal!.session!.getAddress(namespace)!;

    final messageBytes = utf8.encode(message);
    final hexMessage = '0x${hex.encode(messageBytes)}';

    final result = await appKitModal!.request(
      topic: appKitModal!.session!.topic,
      chainId: selectedChainId,
      request: SessionRequestParams(
        method: 'personal_sign',
        params: [
          hexMessage,
          address,
        ],
      ),
    );

    return result.toString();
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API 오류 ${response.statusCode}: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> loginWithWallet() async {
    if (appKitModal == null) return;

    if (!isConnected) {
      setState(() {
        statusMessage = '먼저 MetaMask 지갑을 연결해주세요.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      statusMessage = '로그인 진행 중...';
    });

    try {
      final address = currentWalletAddress;
      final currentChainId = chainId;

      if (currentChainId != 11155111) {
        throw Exception('Sepolia 네트워크로 변경해주세요. 현재 chainId: $currentChainId');
      }

      final nonceResponse = await postJson(
        '/auth/wallet/nonce',
        {
          'walletAddress': address,
          'chainId': currentChainId,
          'walletType': 'METAMASK',
        },
      );

      final nonce = nonceResponse['nonce'];
      final message = nonceResponse['message'];

      if (nonce == null || message == null) {
        throw Exception('서버 응답에 nonce 또는 message가 없습니다.');
      }

      setState(() {
        statusMessage = 'MetaMask에서 서명을 승인해주세요.';
      });

      final signature = await signMessage(message);

      final loginResponse = await postJson(
        '/auth/wallet/login',
        {
          'walletAddress': address,
          'signature': signature,
          'nonce': nonce,
          'chainId': currentChainId,
          'walletType': 'METAMASK',
        },
      );

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('accessToken', loginResponse['accessToken']);
      await prefs.setString('refreshToken', loginResponse['refreshToken']);
      await prefs.setString('walletAddress', address);

      final user = loginResponse['user'];
      if (user != null && user['id'] != null) {
        await prefs.setInt('userId', user['id']);
      }

      final isNewUser = loginResponse['isNewUser'] == true;

      if (!mounted) return;

      setState(() {
        walletAddress = address;
        statusMessage = '로그인 성공';
      });

      if (isNewUser) {
        // 나중에 회원가입/프로필 입력 페이지가 있으면 그쪽으로 변경
        // Navigator.pushReplacementNamed(context, '/edit-profile');
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        statusMessage = '로그인 실패: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

 void goToHomeWithoutWallet() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  String shortAddress(String address) {
    if (address.length < 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final connectedText = walletAddress == null
        ? '연결된 지갑 없음'
        : '연결된 지갑: ${shortAddress(walletAddress!)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('임시 지갑 로그인'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 72,
              ),
              const SizedBox(height: 24),
              const Text(
                'MetaMask 지갑 로그인 테스트',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                connectedText,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isInitializing ? null : connectWallet,
                  child: Text(
                    isInitializing ? '초기화 중...' : 'MetaMask 지갑 연결',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: refreshWalletState,
                  child: const Text('연결 상태 확인'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : loginWithWallet,
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('지갑으로 로그인'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: goToHomeWithoutWallet,
                  child: const Text('지갑 연결 없이 홈으로 이동'),
                ),
              ),
              const SizedBox(height: 24),
              if (statusMessage != null)
                Text(
                  statusMessage!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}