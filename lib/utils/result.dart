// =============================================================================
// result.dart - 타입 안전한 결과 처리 패턴
// =============================================================================

/// 성공 또는 실패를 나타내는 제네릭 결과 타입
/// Dart의 sealed class를 사용한 함수형 에러 처리
sealed class Result<T> {
  const Result();

  /// 성공 결과 생성
  factory Result.success(T data) = Success<T>;

  /// 실패 결과 생성
  factory Result.failure(AppException error) = Failure<T>;

  /// 성공 여부
  bool get isSuccess => this is Success<T>;

  /// 실패 여부
  bool get isFailure => this is Failure<T>;

  /// 성공 시 데이터 반환 (실패 시 null)
  T? get dataOrNull => isSuccess ? (this as Success<T>).data : null;

  /// 실패 시 에러 반환 (성공 시 null)
  AppException? get errorOrNull => isFailure ? (this as Failure<T>).error : null;

  /// 성공 시 데이터 반환, 실패 시 기본값 반환
  T getOrElse(T defaultValue) => isSuccess ? (this as Success<T>).data : defaultValue;

  /// 결과 변환 (map)
  Result<R> map<R>(R Function(T data) transform) {
    if (isSuccess) {
      return Result.success(transform((this as Success<T>).data));
    }
    return Result.failure((this as Failure<T>).error);
  }

  /// 결과에 따른 처리 (fold)
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(AppException error) onFailure,
  }) {
    if (isSuccess) {
      return onSuccess((this as Success<T>).data);
    }
    return onFailure((this as Failure<T>).error);
  }

  /// 성공 시 콜백 실행
  Result<T> onSuccess(void Function(T data) callback) {
    if (isSuccess) {
      callback((this as Success<T>).data);
    }
    return this;
  }

  /// 실패 시 콜백 실행
  Result<T> onFailure(void Function(AppException error) callback) {
    if (isFailure) {
      callback((this as Failure<T>).error);
    }
    return this;
  }
}

/// 성공 결과
final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

/// 실패 결과
final class Failure<T> extends Result<T> {
  final AppException error;
  const Failure(this.error);
}

// =============================================================================
// 앱 예외 클래스
// =============================================================================

/// 에러 종류 열거형
enum ErrorType {
  network,      // 네트워크 오류
  api,          // API 오류
  parse,        // 파싱 오류
  file,         // 파일 오류
  validation,   // 유효성 검사 오류
  permission,   // 권한 오류
  database,     // 데이터베이스 오류
  ocr,          // OCR 오류
  rateLimit,    // #17: 요청 제한 오류
  unknown,      // 알 수 없는 오류
}

/// 앱 전역 예외 클래스
class AppException implements Exception {
  final ErrorType type;
  final String messageKey;
  final String? details;
  final Object? originalError;

  const AppException({
    required this.type,
    required this.messageKey,
    this.details,
    this.originalError,
  });

  // 팩토리 메서드들
  factory AppException.network({String? details, Object? originalError}) {
    return AppException(
      type: ErrorType.network,
      messageKey: 'networkError',
      details: details,
      originalError: originalError,
    );
  }

  factory AppException.api({String? details, Object? originalError}) {
    return AppException(
      type: ErrorType.api,
      messageKey: 'apiError',
      details: details,
      originalError: originalError,
    );
  }

  factory AppException.parse({String? details, Object? originalError}) {
    return AppException(
      type: ErrorType.parse,
      messageKey: 'parseError',
      details: details,
      originalError: originalError,
    );
  }

  factory AppException.file({required String messageKey, String? details, Object? originalError}) {
    return AppException(
      type: ErrorType.file,
      messageKey: messageKey,
      details: details,
      originalError: originalError,
    );
  }

  factory AppException.validation({required String messageKey, String? details}) {
    return AppException(
      type: ErrorType.validation,
      messageKey: messageKey,
      details: details,
    );
  }

  factory AppException.ocr({required String messageKey, String? details, Object? originalError}) {
    return AppException(
      type: ErrorType.ocr,
      messageKey: messageKey,
      details: details,
      originalError: originalError,
    );
  }

  factory AppException.database({String? details, Object? originalError}) {
    return AppException(
      type: ErrorType.database,
      messageKey: 'databaseError',
      details: details,
      originalError: originalError,
    );
  }

  // #17: 요청 제한 예외
  factory AppException.rateLimit({String? details, Object? originalError}) {
    return AppException(
      type: ErrorType.rateLimit,
      messageKey: 'rateLimitExceeded',
      details: details,
      originalError: originalError,
    );
  }

  factory AppException.unknown({Object? originalError}) {
    return AppException(
      type: ErrorType.unknown,
      messageKey: 'unknownError',
      originalError: originalError,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer('AppException($type): $messageKey');
    if (details != null) buffer.write(' - $details');
    return buffer.toString();
  }
}
