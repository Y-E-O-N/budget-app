// =============================================================================
// error_messages.dart - 중앙화된 에러 메시지
// =============================================================================

/// 에러 메시지 관리 클래스
class ErrorMessages {
  ErrorMessages._();

  /// 지원 언어별 에러 메시지
  static const Map<String, Map<String, String>> _messages = {
    'ko': {
      // 네트워크/API 오류
      'networkError': '네트워크 오류',
      'apiError': 'API 오류',
      'connectionTimeout': '연결 시간 초과',
      'serverError': '서버 오류가 발생했습니다',

      // 파일 오류
      'noFileSelected': '파일을 선택하지 않았습니다',
      'fileReadError': '파일을 읽을 수 없습니다',
      'fileWriteError': '파일을 저장할 수 없습니다',
      'invalidFileFormat': '올바른 파일 형식이 아닙니다',
      'fileTooLarge': '파일 크기가 너무 큽니다',

      // 파싱/데이터 오류
      'parseError': '데이터 파싱 오류',
      'invalidFormat': '올바른 형식이 아닙니다',
      'invalidExcelFormat': '올바른 엑셀 형식이 아닙니다',
      'emptyData': '데이터가 비어있습니다',

      // OCR 오류
      'noTextFound': '텍스트를 인식하지 못했습니다',
      'ocrFailed': '영수증 인식에 실패했습니다',
      'cameraPermissionDenied': '카메라 권한이 필요합니다',

      // 유효성 검사 오류
      'requiredField': '필수 입력 항목입니다',
      'invalidAmount': '올바른 금액을 입력해주세요',
      'invalidDate': '올바른 날짜를 입력해주세요',
      'duplicateName': '이미 존재하는 이름입니다',

      // 데이터베이스 오류
      'databaseError': '데이터베이스 오류',
      'saveError': '저장 중 오류가 발생했습니다',
      'deleteError': '삭제 중 오류가 발생했습니다',
      'loadError': '불러오기 중 오류가 발생했습니다',

      // 기타
      'unknownError': '알 수 없는 오류가 발생했습니다',
      'operationCancelled': '작업이 취소되었습니다',
      'retryLater': '잠시 후 다시 시도해주세요',
    },
    'en': {
      // Network/API errors
      'networkError': 'Network error',
      'apiError': 'API error',
      'connectionTimeout': 'Connection timeout',
      'serverError': 'Server error occurred',

      // File errors
      'noFileSelected': 'No file selected',
      'fileReadError': 'Cannot read file',
      'fileWriteError': 'Cannot save file',
      'invalidFileFormat': 'Invalid file format',
      'fileTooLarge': 'File size is too large',

      // Parse/Data errors
      'parseError': 'Data parsing error',
      'invalidFormat': 'Invalid format',
      'invalidExcelFormat': 'Invalid Excel format',
      'emptyData': 'Data is empty',

      // OCR errors
      'noTextFound': 'No text found in image',
      'ocrFailed': 'Failed to process receipt',
      'cameraPermissionDenied': 'Camera permission required',

      // Validation errors
      'requiredField': 'This field is required',
      'invalidAmount': 'Please enter a valid amount',
      'invalidDate': 'Please enter a valid date',
      'duplicateName': 'Name already exists',

      // Database errors
      'databaseError': 'Database error',
      'saveError': 'Error while saving',
      'deleteError': 'Error while deleting',
      'loadError': 'Error while loading',

      // Others
      'unknownError': 'An unknown error occurred',
      'operationCancelled': 'Operation cancelled',
      'retryLater': 'Please try again later',
    },
    'ja': {
      // ネットワーク/APIエラー
      'networkError': 'ネットワークエラー',
      'apiError': 'APIエラー',
      'connectionTimeout': '接続タイムアウト',
      'serverError': 'サーバーエラーが発生しました',

      // ファイルエラー
      'noFileSelected': 'ファイルが選択されていません',
      'fileReadError': 'ファイルを読み込めません',
      'fileWriteError': 'ファイルを保存できません',
      'invalidFileFormat': '無効なファイル形式です',
      'fileTooLarge': 'ファイルサイズが大きすぎます',

      // パース/データエラー
      'parseError': 'データパースエラー',
      'invalidFormat': '無効な形式です',
      'invalidExcelFormat': '無効なExcel形式です',
      'emptyData': 'データが空です',

      // OCRエラー
      'noTextFound': 'テキストが認識できませんでした',
      'ocrFailed': 'レシートの認識に失敗しました',
      'cameraPermissionDenied': 'カメラの許可が必要です',

      // バリデーションエラー
      'requiredField': '必須項目です',
      'invalidAmount': '有効な金額を入力してください',
      'invalidDate': '有効な日付を入力してください',
      'duplicateName': 'この名前は既に存在します',

      // データベースエラー
      'databaseError': 'データベースエラー',
      'saveError': '保存中にエラーが発生しました',
      'deleteError': '削除中にエラーが発生しました',
      'loadError': '読み込み中にエラーが発生しました',

      // その他
      'unknownError': '不明なエラーが発生しました',
      'operationCancelled': '操作がキャンセルされました',
      'retryLater': 'しばらくしてからもう一度お試しください',
    },
  };

  /// 언어별 에러 메시지 가져오기
  static String get(String key, String language) {
    return _messages[language]?[key] ?? _messages['ko']![key] ?? key;
  }

  /// 세부 정보 포함한 에러 메시지 생성
  static String getWithDetails(String key, String language, String? details) {
    final message = get(key, language);
    if (details != null && details.isNotEmpty) {
      return '$message: $details';
    }
    return message;
  }
}
