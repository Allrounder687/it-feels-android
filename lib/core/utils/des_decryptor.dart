import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/desede_engine.dart';
import 'package:pointycastle/block/modes/ecb.dart';

class DesDecryptor {
  static const String _key = '38346591';

  /// Decrypt JioSaavn DES-ECB encrypted_media_url
  static String? decrypt(String encryptedBase64) {
    if (encryptedBase64.isEmpty) return null;
    try {
      // 3DES with K1=K2=K3 (24-byte key) is mathematically identical to single DES
      final key24 = _key + _key + _key;
      final keyBytes = Uint8List.fromList(utf8.encode(key24));
      final cipher = ECBBlockCipher(DESedeEngine());
      cipher.init(false, KeyParameter(keyBytes));

      final encryptedBytes = base64.decode(encryptedBase64);
      final decryptedBytes = Uint8List(encryptedBytes.length);

      final blockSize = cipher.blockSize;
      for (var offset = 0; offset < encryptedBytes.length; offset += blockSize) {
        cipher.processBlock(encryptedBytes, offset, decryptedBytes, offset);
      }

      // Remove PKCS7 padding
      int end = decryptedBytes.length;
      if (end > 0) {
        int paddingLength = decryptedBytes[end - 1];
        if (paddingLength > 0 && paddingLength <= blockSize) {
          end -= paddingLength;
        }
      }

      final decryptedStr = utf8.decode(decryptedBytes.sublist(0, end));
      return decryptedStr;
    } catch (e) {
      debugPrint('[DesDecryptor] Error: $e');
      return null;
    }
  }

  /// Upgrade low quality stream URL to 320kbps high quality AAC/MP4 CDN link
  static String? get320kbpsUrl(String? decryptedLink) {
    if (decryptedLink == null || decryptedLink.isEmpty) return null;

    if (decryptedLink.contains('preview.saavncdn.com')) {
      return decryptedLink
          .replaceAll(RegExp(r'(_96_p|_96|_160)\.(mp3|m4a)$'), '_320.mp4')
          .replaceAll('preview.saavncdn.com', 'aac.saavncdn.com');
    }

    return decryptedLink.replaceAll(RegExp(r'(_96_p|_96|_160)\.(mp3|m4a)$'), '_320.mp4');
  }
}
