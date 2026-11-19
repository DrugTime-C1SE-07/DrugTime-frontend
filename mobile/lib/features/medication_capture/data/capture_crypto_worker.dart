import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

Future<String> sealCapture(Uint8List bytes, String header, List<int> key) =>
    compute(_seal, (bytes, header, Uint8List.fromList(key)));

Future<Uint8List> openCapture(String envelope, String header, List<int> key) =>
    compute(_open, (envelope, header, Uint8List.fromList(key)));

Future<String> _seal((Uint8List, String, Uint8List) data) async {
  final (bytes, header, key) = data;
  try {
    final box = await AesGcm.with256bits()
        .encrypt(bytes, secretKey: SecretKey(key), aad: utf8.encode(header));
    return jsonEncode(
        {'header': header, 'box': base64Encode(box.concatenation())});
  } finally {
    key.fillRange(0, key.length, 0);
  }
}

Future<Uint8List> _open((String, String, Uint8List) data) async {
  final (envelope, header, key) = data;
  try {
    final value = jsonDecode(envelope) as Map<String, dynamic>;
    if (value['header'] != header) {
      throw const FormatException('Invalid capture header');
    }
    final cipher = AesGcm.with256bits();
    final box = SecretBox.fromConcatenation(
        base64Decode(value['box'] as String),
        nonceLength: cipher.nonceLength,
        macLength: cipher.macAlgorithm.macLength);
    return Uint8List.fromList(await cipher.decrypt(box,
        secretKey: SecretKey(key), aad: utf8.encode(header)));
  } finally {
    key.fillRange(0, key.length, 0);
  }
}
