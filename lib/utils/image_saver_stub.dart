// =============================================================================
// image_saver_stub.dart - 이미지 저장 stub (조건부 import용)
// =============================================================================
import 'dart:typed_data';

// 기본 stub - 실제 구현은 플랫폼별 파일에서 제공
Future<bool> saveAndShareImage(Uint8List bytes, String fileName, String shareText) async {
  throw UnsupportedError('Cannot save image without dart:html or dart:io');
}
