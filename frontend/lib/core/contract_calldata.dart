import 'dart:convert';

import 'package:convert/convert.dart';

class ContractCalldata {
  static const String registerImageSelector = '0xf94a3c13';
  static const String updatePriceSelector = '0xcb846a8d';
  static const String purchaseImageSelector = '0x07d5abe1';

  static String registerImage({
    required String pHash,
    required BigInt price,
    required BigInt nonce,
    required BigInt deadline,
    required String signature,
  }) {
    return _encodeStringUintUintUintBytes(
      registerImageSelector,
      pHash,
      price,
      nonce,
      deadline,
      signature,
    );
  }

  static String updatePrice({
    required String pHash,
    required BigInt newPrice,
    required BigInt nonce,
    required BigInt deadline,
    required String signature,
  }) {
    return _encodeStringUintUintUintBytes(
      updatePriceSelector,
      pHash,
      newPrice,
      nonce,
      deadline,
      signature,
    );
  }

  static String purchaseImage({
    required String pHash,
    required BigInt price,
    required BigInt nonce,
    required BigInt deadline,
    required String signature,
  }) {
    return _encodeStringUintUintUintBytes(
      purchaseImageSelector,
      pHash,
      price,
      nonce,
      deadline,
      signature,
    );
  }

  static String _encodeStringUintUintUintBytes(
    String selector,
    String pHash,
    BigInt value,
    BigInt nonce,
    BigInt deadline,
    String signature,
  ) {
    final stringTail = _encodeString(pHash);
    final signatureTail = _encodeDynamicBytes(_strip0x(signature));
    const headSizeBytes = 32 * 5;
    final signatureOffset = headSizeBytes + stringTail.length ~/ 2;

    return selector +
        _encodeUint(BigInt.from(headSizeBytes)) +
        _encodeUint(value) +
        _encodeUint(nonce) +
        _encodeUint(deadline) +
        _encodeUint(BigInt.from(signatureOffset)) +
        stringTail +
        signatureTail;
  }

  static String _encodeString(String value) {
    return _encodeDynamicBytes(hex.encode(utf8.encode(value)));
  }

  static String _encodeDynamicBytes(String hexPayload) {
    if (hexPayload.length.isOdd) {
      throw ArgumentError('Dynamic bytes payload must have even hex length.');
    }
    final byteLength = hexPayload.length ~/ 2;
    final paddedLength = ((hexPayload.length + 63) ~/ 64) * 64;
    return _encodeUint(BigInt.from(byteLength)) +
        hexPayload.padRight(paddedLength, '0');
  }

  static String _encodeUint(BigInt value) {
    if (value < BigInt.zero) {
      throw ArgumentError('uint256 value cannot be negative.');
    }
    final raw = value.toRadixString(16);
    if (raw.length > 64) {
      throw ArgumentError('uint256 value is too large.');
    }
    return raw.padLeft(64, '0');
  }

  static String _strip0x(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('0x') ? trimmed.substring(2) : trimmed;
  }
}
