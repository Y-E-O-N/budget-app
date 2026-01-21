// =============================================================================
// image_saver_web.dart - 웹 환경에서 이미지 다운로드 처리 (#31)
// =============================================================================
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

// 웹에서는 브라우저 다운로드 기능 사용
Future<bool> saveAndShareImage(Uint8List bytes, String fileName, String shareText) async {
  try {
    // bytes를 Blob으로 변환
    final blob = html.Blob([bytes], 'image/png');
    // Blob URL 생성
    final url = html.Url.createObjectUrlFromBlob(blob);
    // 다운로드 링크 생성 및 클릭
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    // DOM에 추가 후 클릭
    html.document.body?.append(anchor);
    anchor.click();
    // 정리
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (e) {
    return false;
  }
}
