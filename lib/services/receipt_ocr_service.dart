// =============================================================================
// receipt_ocr_service.dart - 영수증 OCR 서비스
// =============================================================================
import 'dart:async';
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/result.dart';
import '../constants/error_messages.dart';

// OCR 결과 데이터
class OcrData {
  final int? amount;
  final DateTime? date;
  final String rawText;

  const OcrData({
    this.amount,
    this.date,
    required this.rawText,
  });

  /// 인식된 데이터가 있는지 여부
  bool get hasData => amount != null || date != null;
}

// 기존 호환용 ReceiptOcrResult (deprecated, 추후 제거)
@Deprecated('Use Result<OcrData> instead')
class ReceiptOcrResult {
  final bool success;
  final int? amount;
  final DateTime? date;
  final String? rawText;
  final String? error;

  ReceiptOcrResult({
    required this.success,
    this.amount,
    this.date,
    this.rawText,
    this.error,
  });

  factory ReceiptOcrResult.success({int? amount, DateTime? date, String? rawText}) {
    return ReceiptOcrResult(success: true, amount: amount, date: date, rawText: rawText);
  }

  factory ReceiptOcrResult.failure(String error) {
    return ReceiptOcrResult(success: false, error: error);
  }

  // Result<OcrData>로 변환
  Result<OcrData> toResult() {
    if (success) {
      return Result.success(OcrData(
        amount: amount,
        date: date,
        rawText: rawText ?? '',
      ));
    }
    return Result.failure(AppException.ocr(
      messageKey: 'ocrFailed',
      details: error,
    ));
  }
}

class ReceiptOcrService {
  final String language;
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.korean);

  // 정적 RegExp (한 번만 컴파일)
  static final _keywordPatterns = [
    RegExp(r'(?:결제\s*금액|카드\s*결제|현금\s*결제|총\s*결제|합\s*계\s*금액)[:\s]*([0-9,]+)\s*원?', caseSensitive: false),
    RegExp(r'(?:총\s*액|합\s*계|Total|TOTAL)[:\s]*([0-9,]+)\s*원?', caseSensitive: false),
    RegExp(r'(?:받을\s*금액|받으실\s*금액)[:\s]*([0-9,]+)\s*원?', caseSensitive: false),
  ];
  static final _amountPattern = RegExp(r'([0-9]{1,3}(?:,[0-9]{3})+)\s*원?');
  static final _fullYearPattern = RegExp(r'(20[2-9][0-9])[.\-/]([01]?[0-9])[.\-/]([0-3]?[0-9])');
  static final _shortYearPattern = RegExp(r'([2-9][0-9])[.\-/]([01]?[0-9])[.\-/]([0-3]?[0-9])');
  static final _koreanDatePattern = RegExp(r'(20[2-9][0-9])년\s*([01]?[0-9])월\s*([0-3]?[0-9])일');

  ReceiptOcrService({required this.language});

  // 리소스 해제
  void dispose() {
    _textRecognizer.close();
  }

  // ==========================================================================
  // 새로운 Result 기반 메서드 (권장)
  // ==========================================================================

  /// 이미지 선택 (Result 버전)
  Future<Result<File>> pickImageAsResult(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image == null) {
        return Result.failure(AppException.ocr(messageKey: 'operationCancelled'));
      }
      return Result.success(File(image.path));
    } catch (e) {
      return Result.failure(AppException.ocr(
        messageKey: 'cameraPermissionDenied',
        originalError: e,
      ));
    }
  }

  /// 영수증 처리 (Result 버전)
  Future<Result<OcrData>> process(File imageFile) async {
    try {
      // ML Kit으로 텍스트 인식 (15초 타임아웃)
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage)
          .timeout(const Duration(seconds: 15));
      final String text = recognizedText.text;

      // 텍스트가 비어있으면 실패
      if (text.isEmpty) {
        return Result.failure(AppException.ocr(messageKey: 'noTextFound'));
      }

      // 금액과 날짜 파싱
      return Result.success(OcrData(
        amount: _parseAmount(text),
        date: _parseDate(text),
        rawText: text,
      ));
    } catch (e) {
      return Result.failure(AppException.ocr(
        messageKey: 'ocrFailed',
        originalError: e,
      ));
    }
  }

  /// 에러 메시지 가져오기 (중앙화된 메시지 사용)
  String getErrorMessage(AppException error) {
    return ErrorMessages.getWithDetails(error.messageKey, language, error.details);
  }

  // ==========================================================================
  // 기존 호환용 메서드 (deprecated)
  // ==========================================================================

  @Deprecated('Use pickImageAsResult() instead')
  Future<File?> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image == null) return null;
      return File(image.path);
    } catch (e) {
      return null;
    }
  }

  @Deprecated('Use process() instead')
  Future<ReceiptOcrResult> processReceipt(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage)
          .timeout(const Duration(seconds: 15));
      final String text = recognizedText.text;

      if (text.isEmpty) {
        return ReceiptOcrResult.failure(_getErrorMessage('noTextFound'));
      }

      final int? amount = _parseAmount(text);
      final DateTime? date = _parseDate(text);

      return ReceiptOcrResult.success(amount: amount, date: date, rawText: text);
    } catch (e) {
      return ReceiptOcrResult.failure(_getErrorMessage('ocrFailed'));
    }
  }

  // 금액 파싱 (한국 영수증 패턴)
  int? _parseAmount(String text) {
    final lines = text.split('\n');

    // 패턴 1: 키워드 매칭
    for (final pattern in _keywordPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(',', '');
        final amount = int.tryParse(amountStr ?? '');
        if (amount != null && amount > 0) return amount;
      }
    }

    // 패턴 2: 줄에서 가장 큰 금액 찾기 (1,000 이상)
    int? maxAmount;
    for (final line in lines) {
      final matches = _amountPattern.allMatches(line);
      for (final match in matches) {
        final amountStr = match.group(1)?.replaceAll(',', '');
        final amount = int.tryParse(amountStr ?? '');
        if (amount != null && amount >= 1000) {
          if (maxAmount == null || amount > maxAmount) {
            maxAmount = amount;
          }
        }
      }
    }

    return maxAmount;
  }

  // 날짜 파싱
  DateTime? _parseDate(String text) {
    // 패턴 1: yyyy.MM.dd 또는 yyyy-MM-dd 또는 yyyy/MM/dd
    final match1 = _fullYearPattern.firstMatch(text);
    if (match1 != null) {
      final year = int.tryParse(match1.group(1) ?? '');
      final month = int.tryParse(match1.group(2) ?? '');
      final day = int.tryParse(match1.group(3) ?? '');
      if (year != null && month != null && day != null && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }

    // 패턴 2: yy.MM.dd 또는 yy-MM-dd 또는 yy/MM/dd
    final match2 = _shortYearPattern.firstMatch(text);
    if (match2 != null) {
      final year = 2000 + (int.tryParse(match2.group(1) ?? '') ?? 0);
      final month = int.tryParse(match2.group(2) ?? '');
      final day = int.tryParse(match2.group(3) ?? '');
      if (month != null && day != null && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }

    // 패턴 3: yyyy년 MM월 dd일
    final match3 = _koreanDatePattern.firstMatch(text);
    if (match3 != null) {
      final year = int.tryParse(match3.group(1) ?? '');
      final month = int.tryParse(match3.group(2) ?? '');
      final day = int.tryParse(match3.group(3) ?? '');
      if (year != null && month != null && day != null && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  // 다국어 에러 메시지
  String _getErrorMessage(String key) {
    final messages = {
      'ko': {
        'noTextFound': '텍스트를 인식하지 못했습니다',
        'ocrFailed': '영수증 인식에 실패했습니다',
      },
      'en': {
        'noTextFound': 'No text found in image',
        'ocrFailed': 'Failed to process receipt',
      },
      'ja': {
        'noTextFound': 'テキストが認識できませんでした',
        'ocrFailed': 'レシートの認識に失敗しました',
      },
    };
    return messages[language]?[key] ?? messages['ko']![key]!;
  }
}
