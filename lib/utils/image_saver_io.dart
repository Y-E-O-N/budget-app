// =============================================================================
// image_saver_io.dart - 네이티브(모바일/데스크톱) 환경에서 이미지 공유 처리 (#31)
// =============================================================================
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// 네이티브에서는 파일 저장 후 share_plus로 공유
Future<bool> saveAndShareImage(Uint8List bytes, String fileName, String shareText) async {
  try {
    // 임시 디렉토리에 파일 저장
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    // share_plus로 공유
    await Share.shareXFiles(
      [XFile(file.path)],
      text: shareText,
    );
    return true;
  } catch (e) {
    return false;
  }
}
