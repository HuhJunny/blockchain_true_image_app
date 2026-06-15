import 'dart:convert';

import '../api/auth_api.dart';
import '../core/token_storage.dart';
import '../services/auth_service.dart';
import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  static const String sepoliaChain = 'eip155:11155111';
  static const int sepoliaChainId = 11155111;
  static const String sepoliaHexChainId = '0xaa36a7';
  static const List<String> eip155Methods = [
    'personal_sign',
    'eth_sign',
    'eth_sendTransaction',
    'eth_signTransaction',
    'eth_signTypedData',
    'eth_signTypedData_v4',
    'wallet_switchEthereumChain',
    'wallet_addEthereumChain',
  ];
  static const List<String> eip155Events = ['accountsChanged', 'chainChanged'];
  static const List<String> debugPageMethods = [
    'personal_sign',
    'eth_sign',
    'eth_sendTransaction',
  ];
  static const Map<String, RequiredNamespace> debugPageSepoliaNamespaces = {
    'eip155': RequiredNamespace(
      chains: [sepoliaChain],
      methods: debugPageMethods,
      events: eip155Events,
    ),
  };
  static const Map<String, RequiredNamespace> sepoliaRequiredNamespaces = {
    'eip155': RequiredNamespace(
      chains: [sepoliaChain],
      methods: eip155Methods,
      events: eip155Events,
    ),
  };

  ReownAppKitModalNetworkInfo get sepoliaNetwork {
    final network = ReownAppKitModalNetworks.getNetworkInfo(
      'eip155',
      '11155111',
    );

    if (network == null) {
      throw Exception('Sepolia 네트워크 정보를 찾을 수 없습니다.');
    }

    return network;
  }

  Future<ReownAppKitModal> createFreshSepoliaModal() async {
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
        redirect: Redirect(native: 'imagechain://wc',),
      ),
      optionalNamespaces: debugPageSepoliaNamespaces,
    );

    await modal.init();
    await modal.selectChain(sepoliaNetwork);

    debugPrint(
      '[createFreshSepoliaModal] optionalNamespaces=$debugPageSepoliaNamespaces',
    );

    return modal;
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

      final modal = await createFreshSepoliaModal();

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

  List<String> approvedEip155Chains() {
    final chains = appKitModal?.session?.getApprovedChains() ?? const [];
    return chains.where((chain) => chain.startsWith('eip155:')).toList();
  }

  bool get hasApprovedSepoliaSession {
    return approvedEip155Chains().contains(sepoliaChain);
  }

  void debugWalletSession(String label) {
    final session = appKitModal?.session;
    debugPrint('[$label] isConnected=$isConnected');
    debugPrint('[$label] topic=${session?.topic}');
    debugPrint('[$label] namespaces=${session?.namespaces}');
    debugPrint('[$label] approvedEip155Chains=${approvedEip155Chains()}');
    debugPrint('[$label] eip155Accounts=${eip155Accounts()}');
  }

  Future<bool> ensureApprovedSepoliaSession(String label) async {
    debugWalletSession(label);

    if (!isConnected) {
      return false;
    }

    if (hasApprovedSepoliaSession) {
      return true;
    }

    final upgraded = await requestSepoliaFromApprovedSession(label);
    if (upgraded) {
      return true;
    }

    await appKitModal?.disconnect();
    if (mounted) {
      setState(() {
        walletAddress = null;
        statusMessage =
            '현재 WalletConnect 세션이 Sepolia를 승인하지 않았습니다. 연결을 해제했으니 MetaMask를 다시 연결하고 Sepolia 승인을 확인해주세요.';
      });
    }
    return false;
  }

  Future<bool> requestSepoliaFromApprovedSession(String label) async {
    final modal = appKitModal;
    final session = modal?.session;
    final approvedChains = approvedEip155Chains();

    if (modal == null || session == null || approvedChains.isEmpty) {
      return false;
    }

    final requestChain = approvedChains.contains('eip155:1')
        ? 'eip155:1'
        : approvedChains.first;

    try {
      debugPrint(
        '[$label] requesting wallet_switchEthereumChain through $requestChain',
      );

      await modal.request(
        topic: session.topic,
        chainId: requestChain,
        request: SessionRequestParams(
          method: 'wallet_switchEthereumChain',
          params: [
            {'chainId': sepoliaHexChainId},
          ],
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await selectSepolia();
      debugWalletSession('$label.afterSwitch');
      return hasApprovedSepoliaSession;
    } catch (switchError) {
      debugPrint('[$label] wallet_switchEthereumChain failed: $switchError');

      try {
        debugPrint('[$label] requesting wallet_addEthereumChain');
        await modal.request(
          topic: session.topic,
          chainId: requestChain,
          request: SessionRequestParams(
            method: 'wallet_addEthereumChain',
            params: [
              {
                'chainId': sepoliaHexChainId,
                'chainName': 'Sepolia',
                'nativeCurrency': {
                  'name': 'Sepolia Ether',
                  'symbol': 'ETH',
                  'decimals': 18,
                },
                'rpcUrls': ['https://rpc.sepolia.org'],
                'blockExplorerUrls': ['https://sepolia.etherscan.io'],
              },
            ],
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 1200));
        await selectSepolia();
        debugWalletSession('$label.afterAddChain');
        return hasApprovedSepoliaSession;
      } catch (addError) {
        debugPrint('[$label] wallet_addEthereumChain failed: $addError');
        return false;
      }
    }
  }

  String get selectedChainId {
    return sepoliaChain;
  }

  int get chainId {
    return sepoliaChainId;
  }

  List<String> eip155Accounts() {
    final accounts = appKitModal?.session?.getAccounts() ?? const [];
    return accounts.where((account) => account.startsWith('eip155:')).toList();
  }

  String get currentWalletAddress {
    final accounts = eip155Accounts();
    for (final account in accounts) {
      if (account.startsWith('$sepoliaChain:')) {
        return account.split(':').last;
      }
    }

    final address = appKitModal!.session!.getAddress('eip155');

    if (address == null) {
      if (accounts.isNotEmpty) {
        return accounts.first.split(':').last;
      }

      throw Exception('EVM 지갑 주소를 찾을 수 없습니다.');
    }

    return address;
  }

  Future<void> openMetaMaskWithWalletConnectUri(String wcUri) async {
    final encodedUri = Uri.encodeComponent(wcUri);
    final nativeLink = 'metamask://wc?uri=$encodedUri';
    final universalLink = 'https://metamask.app.link/wc?uri=$encodedUri';

    debugPrint('[connectWallet] wcUri=$wcUri');
    debugPrint('[connectWallet] metamaskNativeLink=$nativeLink');

    final openedNative = await ReownCoreUtils.openURL(nativeLink);
    if (openedNative) {
      return;
    }

    await ReownCoreUtils.openURL(universalLink);
  }

  Future<void> connectSepoliaDirectly() async {
    final appKit = appKitModal?.appKit;
    if (appKit == null) {
      throw Exception('Reown AppKit is not ready.');
    }

    await appKitModal!.reconnectRelay();

    debugPrint('[connectWallet] requiredNamespaces=$sepoliaRequiredNamespaces');
    final connectResponse = await appKit.connect(
      // ignore: deprecated_member_use
      requiredNamespaces: sepoliaRequiredNamespaces,
    );

    final wcUri = connectResponse.uri?.toString();
    if (wcUri == null || wcUri.isEmpty) {
      throw Exception('WalletConnect URI was not created.');
    }

    await openMetaMaskWithWalletConnectUri(wcUri);

    connectResponse.session.future
        .then((_) async {
          if (!hasApprovedSepoliaSession) {
            await requestSepoliaFromApprovedSession(
              'connectWallet.sessionApproved',
            );
          }
          debugWalletSession('connectWallet.sessionApproved');
          if (!mounted) return;
          setState(() {
            statusMessage = hasApprovedSepoliaSession
                ? 'Sepolia WalletConnect 세션 승인 완료'
                : '지갑은 연결됐지만 Sepolia가 승인되지 않았습니다. 상태 확인을 눌러 로그를 확인해주세요.';
          });
        })
        .catchError((Object error) {
          debugPrint('[connectWallet] session approval failed: $error');
          if (!mounted) return;
          setState(() {
            statusMessage = 'MetaMask 연결 승인 실패: $error';
          });
        });
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

      if (isConnected) {
        final isSepoliaReady = await ensureApprovedSepoliaSession(
          'connectWallet.existingSession',
        );
        if (!isSepoliaReady) {
          return;
        }
      } else {
        await connectSepoliaDirectly();
      }

      setState(() {
        statusMessage = hasApprovedSepoliaSession
            ? 'Sepolia WalletConnect 세션이 준비되었습니다.'
            : 'MetaMask에서 Sepolia 연결을 승인해주세요.';
      });
    } catch (e) {
      setState(() {
        statusMessage = '지갑 연결 실패: $e';
      });
    }
  }

  Future<void> connectFreshSepoliaWallet() async {
    try {
      setState(() {
        statusMessage = 'Sepolia fresh WalletConnect 세션을 준비 중입니다...';
      });

      if (appKitModal?.isConnected == true) {
        await appKitModal?.disconnect();
      }

      final freshModal = await createFreshSepoliaModal();
      if (!mounted) return;

      setState(() {
        appKitModal = freshModal;
        walletAddress = null;
        statusMessage = 'MetaMask에서 새 Sepolia 세션을 승인해주세요.';
      });

      await freshModal.openModalView();
    } catch (e) {
      if (!mounted) return;
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

    final isSepoliaApproved = await ensureApprovedSepoliaSession(
      'refreshWalletState',
    );
    if (!isSepoliaApproved) {
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

    final address = currentWalletAddress;

    if (address.isEmpty) {
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

  Future<void> loginWithWallet() async {
    if (appKitModal == null) return;

    if (!isConnected) {
      setState(() {
        statusMessage = '먼저 MetaMask 지갑을 연결해주세요.';
      });
      return;
    }

    final isSepoliaApproved = await ensureApprovedSepoliaSession(
      'loginWithWallet',
    );
    if (!isSepoliaApproved) {
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

      final nonceResponse = await AuthApi.requestNonce(
        address,
        chainId: currentChainId,
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

      final loginResponse = await AuthService.login(
        address,
        signature,
        nonce.toString(),
        chainId: currentChainId,
      );

      final prefs = await SharedPreferences.getInstance();

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
          MaterialPageRoute(builder: (_) => HomePage(appKitModal: appKitModal)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(appKitModal: appKitModal)),
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

      await TokenStorage.clear();

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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomePage(appKitModal: appKitModal)),
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
                  onPressed: isInitializing ? null : connectFreshSepoliaWallet,
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
