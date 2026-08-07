import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/desede_engine.dart';
import 'package:pointycastle/block/modes/ecb.dart';

class DesDecryptor {
  static const String _fallbackKey = '38346591'; // Original hardcoded key as fallback/initial value

  static Future<String> _getSecureKey({Function(String message)? onError}) async {
    // Note: To support Windows without requiring C++ ATL, and since the key is
    // currently hardcoded anyway, we just return the hardcoded key directly.
    return _fallbackKey;
  }

  /// Decrypt Music API DES-ECB encrypted_media_url
  static Future<String?> decrypt(String encryptedBase64, {Function(String message)? onError}) async {
    if (encryptedBase64.isEmpty) return null;
    
    // Check if it is already a decrypted URL (unencrypted stream links)
    if (encryptedBase64.startsWith('http://') || encryptedBase64.startsWith('https://')) {
      return encryptedBase64;
    }
    
    try {
      final desKey = await _getSecureKey(onError: onError);
      // 3DES with K1=K2=K3 (24-byte key) is mathematically identical to single DES
      final key24 = desKey + desKey + desKey; // Use the retrieved secure key
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
      final errorMessage = 'Decryption error: $e';
      onError?.call('Failed to decrypt audio stream.');
      debugPrint('[DesDecryptor] $errorMessage');
      return null;
    }
  }

  /// Upgrade low quality stream URL to 320kbps high quality AAC/MP4 CDN link
  static String? get320kbpsUrl(String? decryptedLink) {
    if (decryptedLink == null || decryptedLink.isEmpty) return null;

    String httpsUrl = decryptedLink.replaceFirst('http://', 'https://');

    if (httpsUrl.contains('preview.saavncdn.com')) {
      return httpsUrl
          .replaceAll(RegExp(r'(_96_p|_96|_160)\.(mp3|m4a)$'), '_320.mp4')
          .replaceAll('preview.saavncdn.com', 'aac.saavncdn.com');
    }

    return httpsUrl.replaceAll(RegExp(r'(_96_p|_96|_160)\.(mp3|m4a)$'), '_320.mp4');
  }

  /// Downgrade high quality stream URL to 96kbps low quality MP4 CDN link for slow networks
  static String? get96kbpsUrl(String? originalLink) {
    if (originalLink == null || originalLink.isEmpty) return null;

    String url = originalLink;
    if (url.contains('_320.mp4')) {
      return url.replaceAll('_320.mp4', '_96.mp4');
    } else if (url.contains('_160.mp4')) {
      return url.replaceAll('_160.mp4', '_96.mp4');
    }
    
    return url;
  }
}
