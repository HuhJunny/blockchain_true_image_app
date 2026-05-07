import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'home_page.dart';

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

  // 원래 세폴리아 체인 ID는 eip155:11155111
  // 그러나 현재 메타마스크가 세폴리아 테스트넷을 승인하지 않는 상황
  // Mainnet 체인 ID로 임시 접속
  // 이후 코드에도 전부 대체해 놓음
  // static const String sepoliaChain = 'eip155:11155111';
  // static const int sepoliaChainId = 11155111;
  static const String sepoliaChain = 'eip155:1';
  static const int sepoliaChainId = 1;

  ReownAppKitModalNetworkInfo get sepoliaNetwork {
    final network = ReownAppKitModalNetworks.getNetworkInfo(
      'eip155',
      // '11155111',
      '1',
    );

    if (network == null) {
      throw Exception('Sepolia 네트워크 정보를 찾을 수 없습니다.');
    }

    return network;
  }

  Future<void> selectSepolia({bool requestWalletSwitch = false}) async {
    if (appKitModal == null) return;

    final sepolia = sepoliaNetwork;

    // 앱 내부 selectedChain을 Sepolia로 변경
    await appKitModal!.selectChain(sepolia);

    // 이미 지갑이 연결된 상태라면 MetaMask에도 Sepolia 전환 요청
    if (requestWalletSwitch && isConnected) {
      await appKitModal!.requestSwitchToChain(sepolia);
      await appKitModal!.selectChain(sepolia);
    }
  }

  // TODO: 백엔드 주소에 맞게 수정
  // Android 에뮬레이터에서 로컬 서버면 http://10.0.2.2:4000
  // Chrome에서 로컬 서버면 http://localhost:4000
  // 개인 모바일 기기 연결해서 하는 경우면 ipconfig 쳐서 나오는 WiFi IPv4 주소:4000
  static const String baseUrl = 'http://:4000';

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
          redirect: Redirect(native: 'imagechain://'),
        ),
        optionalNamespaces: {
          'eip155': RequiredNamespace.fromJson({
            // 'chains': ['eip155:11155111'],
            'chains': ['eip155:1'],
            'methods': [
              'personal_sign',
              'eth_sign',
              'eth_sendTransaction',
              'eth_signTransaction',
              'eth_signTypedData',
              'eth_signTypedData_v4',
            ],
            'events': ['accountsChanged', 'chainChanged'],
          }),
        },
      );

      await modal.init();

      final sepolia = ReownAppKitModalNetworks.getNetworkInfo(
        'eip155',
        // '11155111',
        '1',
      );

      if (sepolia != null) {
        await modal.selectChain(sepolia);
      }

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
    return sepoliaChain;
  }

  int get chainId {
    return sepoliaChainId;
  }

  String get currentWalletAddress {
    final address = appKitModal!.session!.getAddress('eip155');

    if (address == null) {
      throw Exception('EVM 지갑 주소를 찾을 수 없습니다.');
    }

    return address;
  }

  Future<void> connectWallet() async {
    if (appKitModal == null) {
      setState(() {
        statusMessage = '아직 Reown 초기화가 끝나지 않았습니다.';
      });
      return;
    }

    try {
      await selectSepolia();

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

    const namespace = 'eip155';

    final address = appKitModal!.session!.getAddress(namespace);

    if (address == null) {
      throw Exception('서명에 사용할 지갑 주소를 찾을 수 없습니다.');
    }

    final messageBytes = utf8.encode(message);
    final hexMessage = '0x${hex.encode(messageBytes)}';

    final result = await appKitModal!.request(
      topic: appKitModal!.session!.topic,
      chainId: selectedChainId,
      request: SessionRequestParams(
        method: 'personal_sign',
        params: [hexMessage, address],
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
      headers: {'Content-Type': 'application/json'},
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
      await selectSepolia(requestWalletSwitch: false);

      final address = currentWalletAddress;
      final currentChainId = chainId;

      if (currentChainId != sepoliaChainId) {
        throw Exception('Sepolia 네트워크로 변경해주세요. 현재 chainId: $currentChainId');
      }

      final nonceResponse = await postJson('/auth/wallet/nonce', {
        'walletAddress': address,
        'chainId': currentChainId,
        'walletType': 'METAMASK',
      });

      final nonce = nonceResponse['nonce'];
      final message = nonceResponse['message'];

      if (nonce == null || message == null) {
        throw Exception('서버 응답에 nonce 또는 message가 없습니다.');
      }

      setState(() {
        statusMessage = 'MetaMask에서 서명을 승인해주세요.';
      });

      final signature = await signMessage(message);

      final loginResponse = await postJson('/auth/wallet/login', {
        'walletAddress': address,
        'signature': signature,
        'nonce': nonce,
        'chainId': currentChainId,
        'walletType': 'METAMASK',
      });

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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(appKitModal: appKitModal!),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(appKitModal: appKitModal!),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('로그인 실패 오류: $e');
      debugPrint('로그인 실패 스택: $stackTrace');

      if (!mounted) return;

      setState(() {
        statusMessage = '로그인 실패: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> disconnectWallet() async {
    try {
      await appKitModal?.disconnect();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
      await prefs.remove('walletAddress');
      await prefs.remove('userId');

      if (!mounted) return;

      setState(() {
        walletAddress = null;
        statusMessage = '지갑 연결 해제됨';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        statusMessage = '지갑 연결 해제 실패: $e';
      });
    }
  }

  void goToHomeWithoutWallet() {
    if (appKitModal == null) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomePage(appKitModal: appKitModal!)),
    );
  }

  String shortAddress(String address) {
    if (address.length < 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final connectedText = walletAddress == null
        ? '연결된 지갑 없음'
        : shortAddress(walletAddress!);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: goToHomeWithoutWallet,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.black87,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wallet Login',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'MetaMask 지갑 연결',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 42,
                      color: Colors.black87,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Block Snap 지갑 인증',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '이미지 등록과 검증 기능을 사용하기 위해 MetaMask 지갑을 연결합니다.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            walletAddress == null ? Icons.link_off : Icons.link,
                            size: 20,
                            color: walletAddress == null
                                ? Colors.black45
                                : Colors.blue,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              walletAddress == null
                                  ? '지갑이 아직 연결되지 않았습니다.'
                                  : '연결된 지갑: $connectedText',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: walletAddress == null
                                    ? Colors.black54
                                    : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: isInitializing ? null : connectWallet,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: Text(isInitializing ? '초기화 중...' : 'MetaMask 지갑 연결'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: refreshWalletState,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('상태 확인'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: disconnectWallet,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('연결 해제'),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: isLoading ? null : loginWithWallet,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('지갑으로 로그인'),
                ),
              ),

              if (statusMessage != null) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    statusMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
