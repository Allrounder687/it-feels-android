import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/block/desede_engine.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';
import 'package:pointycastle/pointycastle.dart';

class DesDecryptor {
  static const String _saavnDesKey = '383465913834659138346591';

  static Future<String?> decrypt(String encryptedBase64, {Function(String message)? onError}) async {
    try {
      final trimmed = encryptedBase64.trim();
      if (trimmed.isEmpty) return null;

      // If already a direct HTTP(S) stream or file path, return as is
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://') || trimmed.startsWith('/')) {
        return trimmed;
      }

      final keyBytes = utf8.encode(_saavnDesKey);
      final cipher = PaddedBlockCipherImpl(
        PKCS7Padding(),
        DESedeEngine(),
      );
      final params = PaddedBlockCipherParameters<KeyParameter, Null>(
        KeyParameter(Uint8List.fromList(keyBytes)),
        null,
      );
      cipher.init(false, params); // false = decrypt

      final encBytes = base64Decode(trimmed);
      final decBytes = cipher.process(Uint8List.fromList(encBytes));
      String url = utf8.decode(decBytes);
      url = url.replaceFirst('http://', 'https://');
      url = url.replaceAll('preview.saavncdn.com', 'aac.saavncdn.com');
      url = url.replaceAll('_96.mp4', '_320.mp4').replaceAll('_160.mp4', '_320.mp4');
      return url;
    } catch (e) {
      onError?.call(e.toString());
      debugPrint('[DesDecryptor] Decryption error: $e');
      return null;
    }
  }

  static String? get320kbpsUrl(String? decryptedLink) {
    if (decryptedLink == null || decryptedLink.isEmpty) return null;
    return decryptedLink
        .replaceFirst('http://', 'https://')
        .replaceAll('preview.saavncdn.com', 'aac.saavncdn.com')
        .replaceAll('_96.mp4', '_320.mp4')
        .replaceAll('_160.mp4', '_320.mp4')
        .replaceAll('_96.mp3', '_320.mp4')
        .replaceAll('_160.mp3', '_320.mp4')
        .replaceAll('_160.m4a', '_320.mp4')
        .replaceAll('_96.m4a', '_320.mp4');
  }

  static String? get96kbpsUrl(String? originalLink) {
    if (originalLink == null || originalLink.isEmpty) return null;
    return originalLink
        .replaceAll('_320.mp4', '_96.mp4')
        .replaceAll('_160.mp4', '_96.mp4');
  }
}
