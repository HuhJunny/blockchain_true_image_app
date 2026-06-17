import 'api_client.dart';

class ContractApproval {
  final String action;
  final String contractAddress;
  final String backendSigner;
  final String actor;
  final String pHash;
  final BigInt price;
  final BigInt nonce;
  final BigInt deadline;
  final String approvalHash;
  final String signature;

  const ContractApproval({
    required this.action,
    required this.contractAddress,
    required this.backendSigner,
    required this.actor,
    required this.pHash,
    required this.price,
    required this.nonce,
    required this.deadline,
    required this.approvalHash,
    required this.signature,
  });

  factory ContractApproval.fromJson(dynamic raw) {
    final json = Map<String, dynamic>.from(raw as Map);
    return ContractApproval(
      action: (json['action'] ?? '').toString(),
      contractAddress: (json['contractAddress'] ?? '').toString(),
      backendSigner: (json['backendSigner'] ?? '').toString(),
      actor: (json['actor'] ?? '').toString(),
      pHash: (json['pHash'] ?? '').toString(),
      price: BigInt.parse((json['price'] ?? '0').toString()),
      nonce: BigInt.parse((json['nonce'] ?? '0').toString()),
      deadline: BigInt.parse((json['deadline'] ?? '0').toString()),
      approvalHash: (json['approvalHash'] ?? '').toString(),
      signature: (json['signature'] ?? '').toString(),
    );
  }
}

class ContractApprovalApi {
  static Future<ContractApproval> requestRegister({
    required String pHash,
    required BigInt price,
  }) async {
    final data = await ApiClient.post('/contract-approvals/register', {
      'pHash': pHash,
      'price': price.toString(),
    });
    return ContractApproval.fromJson(data);
  }

  static Future<ContractApproval> requestUpdatePrice({
    required int imageId,
    required String pHash,
    required BigInt price,
  }) async {
    final data = await ApiClient.post('/contract-approvals/update-price', {
      'imageId': imageId,
      'pHash': pHash,
      'price': price.toString(),
    });
    return ContractApproval.fromJson(data);
  }

  static Future<ContractApproval> requestPurchase({
    required int imageId,
    required String pHash,
    required BigInt price,
  }) async {
    final data = await ApiClient.post('/contract-approvals/purchase', {
      'imageId': imageId,
      'pHash': pHash,
      'price': price.toString(),
    });
    return ContractApproval.fromJson(data);
  }
}
