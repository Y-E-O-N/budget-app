// =============================================================================
// secure_storage_service.dart - Hive 암호화 키 관리 서비스
// =============================================================================
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive 암호화 키를 안전하게 생성하고 관리하는 서비스
class SecureStorageService {
  // 암호화 키 저장소
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // 암호화 키 저장 키 이름
  static const _encryptionKeyName = 'hive_encryption_key';

  /// Hive 암호화 키 생성 또는 불러오기
  /// 기존 키가 손상된 경우 예외를 발생시킴 (데이터 손실 방지)
  static Future<Uint8List> getEncryptionKey() async {
    final existingKey = await _storage.read(key: _encryptionKeyName);
    if (existingKey != null) {
      try {
        final decoded = base64Decode(existingKey);
        if (decoded.length == 32) return decoded;
        // 길이 불일치 → 기존 데이터가 있을 수 있으므로 예외 발생
        throw const FormatException('Encryption key is not 32 bytes');
      } catch (e) {
        if (e is FormatException) rethrow;
        // base64 디코딩 실패 → 키 손상
        throw FormatException('Encryption key is corrupted: $e');
      }
    }

    // 키가 없음 → 최초 생성 (안전)
    final newKey = Hive.generateSecureKey();
    await _storage.write(key: _encryptionKeyName, value: base64Encode(newKey));
    return Uint8List.fromList(newKey);
  }

  /// 암호화 박스 열기
  static Future<Box<E>> openEncryptedBox<E>(String name) async {
    final key = await getEncryptionKey();
    return Hive.openBox<E>(
      name,
      encryptionCipher: HiveAesCipher(key),
    );
  }

  /// 암호화 LazyBox 열기 (대용량 데이터용)
  static Future<LazyBox<E>> openEncryptedLazyBox<E>(String name) async {
    final key = await getEncryptionKey();
    return Hive.openLazyBox<E>(
      name,
      encryptionCipher: HiveAesCipher(key),
    );
  }
}
