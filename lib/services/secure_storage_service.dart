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
  static Future<Uint8List> getEncryptionKey() async {
    // 기존 키가 있으면 불러오기
    final existingKey = await _storage.read(key: _encryptionKeyName);
    if (existingKey != null) {
      return base64Decode(existingKey);
    }

    // 새 키 생성 (32바이트 = 256비트)
    final newKey = Hive.generateSecureKey();
    // 안전한 저장소에 저장
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
