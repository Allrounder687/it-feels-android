import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/desede_engine.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Import secure storage

class DesDecryptor {
  // Using a constant for the storage key, not the decryption key itself.
  static const String _secureStorageKey = 'jiosaavn_des_key';
  static const String _fallbackKey = '38346591'; // Original hardcoded key as fallback/initial value

  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Asynchronously retrieves the DES decryption key from secure storage.
  /// If the key is not found, it stores the [_fallbackKey] and then retrieves it.
  ///
  /// **Security Note:** While `flutter_secure_storage` is used, hardcoding a fallback
  /// key (even for initial storage) means it's still present in the codebase.
  /// For true security, this initial key should ideally come from a secure remote source
  /// or be generated and protected uniquely per installation, not embedded.
  static Future<String> _getSecureKey({Function(String message)? onError}) async {
    String? key = await _secureStorage.read(key: _secureStorageKey);
    if (key == null || key.isEmpty) {
      // Store the fallback key if not present (first run)
      await _secureStorage.write(key: _secureStorageKey, value: _fallbackKey);
      key = _fallbackKey;
      if (kDebugMode) {
        debugPrint('[DesDecryptor] Stored and using fallback DES key.');
      }
    }
    return key;
  }

  /// Decrypt JioSaavn DES-ECB encrypted_media_url
  static Future<String?> decrypt(String encryptedBase64, {Function(String message)? onError}) async {
    if (encryptedBase64.isEmpty) return null;
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

    if (decryptedLink.contains('preview.saavncdn.com')) {
      return decryptedLink
          .replaceAll(RegExp(r'(_96_p|_96|_160)\.(mp3|m4a)$'), '_320.mp4')
          .replaceAll('preview.saavncdn.com', 'aac.saavncdn.com');
    }

    return decryptedLink.replaceAll(RegExp(r'(_96_p|_96|_160)\.(mp3|m4a)$'), '_320.mp4');
  }
}
