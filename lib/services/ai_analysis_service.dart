// =============================================================================
// ai_analysis_service.dart - AI 분석 서비스 (백엔드 프록시 방식)
// =============================================================================
// #17: device_id 기반 일일 3회 제한 지원
// #13: 잔여 기간 지출 계획 조언 지원
// =============================================================================
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../utils/result.dart';
import '../constants/error_messages.dart';
import '../constants/app_constants.dart';

// =============================================================================
// 응답 스키마 정의
// =============================================================================
class AiAnalysisResponse {
  final String oneLiner;  // 한 마디 요약 (톤 강하게 반영)
  final String summary;
  final List<String> insights;
  final List<String> warnings;
  final List<String> suggestions;
  final String spendingPlan;  // #13: 잔여 기간 지출 계획 조언
  final SpendingPattern pattern;
  final int remainingAnalyses;  // #17: 남은 분석 횟수
  final String? error;

  AiAnalysisResponse({
    required this.oneLiner,
    required this.summary,
    required this.insights,
    required this.warnings,
    required this.suggestions,
    required this.spendingPlan,
    required this.pattern,
    required this.remainingAnalyses,
    this.error,
  });

  factory AiAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return AiAnalysisResponse(
      oneLiner: json['oneLiner'] ?? '',
      summary: json['summary'] ?? '',
      insights: List<String>.from(json['insights'] ?? []),
      warnings: List<String>.from(json['warnings'] ?? []),
      suggestions: List<String>.from(json['suggestions'] ?? []),
      spendingPlan: json['spendingPlan'] ?? '',  // #13
      pattern: SpendingPattern.fromJson(json['pattern'] ?? {}),
      remainingAnalyses: json['remainingAnalyses'] ?? 0,  // #17
    );
  }

  factory AiAnalysisResponse.error(String message) {
    return AiAnalysisResponse(
      oneLiner: '',
      summary: '',
      insights: [],
      warnings: [],
      suggestions: [],
      spendingPlan: '',
      pattern: SpendingPattern.empty(),
      remainingAnalyses: 0,
      error: message,
    );
  }
}

class SpendingPattern {
  final String mainCategory;
  final String spendingTrend;
  final int savingPotential;
  final String riskLevel;

  SpendingPattern({
    required this.mainCategory,
    required this.spendingTrend,
    required this.savingPotential,
    required this.riskLevel,
  });

  factory SpendingPattern.fromJson(Map<String, dynamic> json) {
    return SpendingPattern(
      mainCategory: json['mainCategory'] ?? '',
      spendingTrend: json['spendingTrend'] ?? '',
      savingPotential: json['savingPotential'] ?? 0,
      riskLevel: json['riskLevel'] ?? 'low',
    );
  }

  factory SpendingPattern.empty() {
    return SpendingPattern(
      mainCategory: '',
      spendingTrend: '',
      savingPotential: 0,
      riskLevel: 'low',
    );
  }
}

// =============================================================================
// #17: 사용량 응답 모델
// =============================================================================
class UsageInfo {
  final String deviceId;
  final String date;
  final int count;
  final int limit;
  final int remaining;

  UsageInfo({
    required this.deviceId,
    required this.date,
    required this.count,
    required this.limit,
    required this.remaining,
  });

  factory UsageInfo.fromJson(Map<String, dynamic> json) {
    return UsageInfo(
      deviceId: json['device_id'] ?? '',
      date: json['date'] ?? '',
      count: json['count'] ?? 0,
      limit: json['limit'] ?? 3,
      remaining: json['remaining'] ?? 0,
    );
  }
}

// =============================================================================
// AI 분석 서비스 (백엔드 프록시 호출)
// =============================================================================
class AiAnalysisService {
  final String language;
  static const String _deviceIdKey = 'ai_device_id';
  static const String _settingsBoxName = 'settings';

  // 보안 저장소 (Device ID 저장용)
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  AiAnalysisService({required this.language, String? apiKey});

  // ==========================================================================
  // #17: Device ID 관리 (보안 저장소 사용)
  // ==========================================================================

  /// 기기 고유 ID 가져오기 (보안 저장소에서, 없으면 생성하여 저장)
  Future<String> getDeviceId() async {
    // 보안 저장소에서 먼저 확인
    String? deviceId = await _secureStorage.read(key: _deviceIdKey);

    // 없으면 기존 Hive에서 마이그레이션 시도
    if (deviceId == null || deviceId.isEmpty) {
      final box = await Hive.openBox(_settingsBoxName);
      final oldDeviceId = box.get(_deviceIdKey);
      if (oldDeviceId != null && oldDeviceId.isNotEmpty) {
        // 보안 저장소로 마이그레이션
        await _secureStorage.write(key: _deviceIdKey, value: oldDeviceId);
        await box.delete(_deviceIdKey);  // 기존 Hive에서 삭제
        deviceId = oldDeviceId;
      }
    }

    // 여전히 없으면 새로 생성
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await _secureStorage.write(key: _deviceIdKey, value: deviceId);
    }
    return deviceId;
  }

  /// 현재 사용량 조회
  Future<Result<UsageInfo>> getUsage() async {
    try {
      final deviceId = await getDeviceId();
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/usage/$deviceId');
      final response = await http.get(url).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Result.success(UsageInfo.fromJson(json));
      }
      return Result.failure(AppException.api(details: 'Failed to get usage info'));
    } catch (e) {
      return Result.failure(AppException.network(originalError: e));
    }
  }

  // ==========================================================================
  // 분석 메서드 (Result 기반)
  // ==========================================================================

  /// 분석 요청 (Result 버전) - #17: device_id 포함
  Future<Result<AiAnalysisResponse>> analyzeWithResult(
    String markdownData, {
    String tone = 'gentle',
  }) async {
    try {
      // #17: device_id 가져오기
      final deviceId = await getDeviceId();
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/analyze');

      // 백엔드로 요청 (#17: device_id 추가)
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': markdownData,
          'language': language,
          'tone': tone,
          'device_id': deviceId,  // #17: 기기 고유 ID
        }),
      ).timeout(AppConstants.apiTimeout);

      // 성공
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return Result.success(AiAnalysisResponse.fromJson(jsonResponse));
      }

      // #17: 429 Rate Limit 에러 처리
      if (response.statusCode == 429) {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['detail'] ?? ErrorMessages.get('rateLimitExceeded', language);
        return Result.failure(AppException.rateLimit(details: errorMessage));
      }

      // API 에러
      final errorBody = jsonDecode(response.body);
      final errorMessage = errorBody['detail'] ?? errorBody['error'] ?? 'Unknown error';
      return Result.failure(AppException.api(details: errorMessage));
    } on TimeoutException {
      return Result.failure(AppException.network(
        details: ErrorMessages.get('connectionTimeout', language),
      ));
    } catch (e) {
      return Result.failure(AppException.network(originalError: e));
    }
  }

  /// 에러 메시지 가져오기 (중앙화된 메시지 사용)
  String getErrorMessage(AppException error) {
    return ErrorMessages.getWithDetails(error.messageKey, language, error.details);
  }

  // ==========================================================================
  // 기존 호환용 메서드 (deprecated)
  // ==========================================================================

  @Deprecated('Use analyzeWithResult() instead')
  Future<AiAnalysisResponse> analyze(String markdownData, {String tone = 'gentle'}) async {
    try {
      final deviceId = await getDeviceId();
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/analyze');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': markdownData,
          'language': language,
          'tone': tone,
          'device_id': deviceId,
        }),
      ).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return AiAnalysisResponse.fromJson(jsonResponse);
      } else if (response.statusCode == 429) {
        // #17: Rate limit error
        final errorBody = jsonDecode(response.body);
        return AiAnalysisResponse.error(errorBody['detail'] ?? _getErrorMessage('rateLimitExceeded'));
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['detail'] ?? errorBody['error'] ?? 'Unknown error';
        return AiAnalysisResponse.error('${_getErrorMessage('apiError')}: $errorMessage');
      }
    } catch (e) {
      return AiAnalysisResponse.error('${_getErrorMessage('networkError')}: $e');
    }
  }

  String _getErrorMessage(String key) {
    return ErrorMessages.get(key, language);
  }
}
