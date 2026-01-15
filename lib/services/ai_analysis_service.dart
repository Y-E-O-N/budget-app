// =============================================================================
// ai_analysis_service.dart - AI 분석 서비스 (백엔드 프록시 방식)
// =============================================================================
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
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
  final SpendingPattern pattern;
  final String? error;

  AiAnalysisResponse({
    required this.oneLiner,
    required this.summary,
    required this.insights,
    required this.warnings,
    required this.suggestions,
    required this.pattern,
    this.error,
  });

  factory AiAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return AiAnalysisResponse(
      oneLiner: json['oneLiner'] ?? '',
      summary: json['summary'] ?? '',
      insights: List<String>.from(json['insights'] ?? []),
      warnings: List<String>.from(json['warnings'] ?? []),
      suggestions: List<String>.from(json['suggestions'] ?? []),
      pattern: SpendingPattern.fromJson(json['pattern'] ?? {}),
    );
  }

  factory AiAnalysisResponse.error(String message) {
    return AiAnalysisResponse(
      oneLiner: '',
      summary: '',
      insights: [],
      warnings: [],
      suggestions: [],
      pattern: SpendingPattern.empty(),
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
// AI 분석 서비스 (백엔드 프록시 호출)
// =============================================================================
class AiAnalysisService {
  final String language;

  AiAnalysisService({required this.language, String? apiKey});

  // ==========================================================================
  // 새로운 Result 기반 메서드 (권장)
  // ==========================================================================

  /// 분석 요청 (Result 버전)
  Future<Result<AiAnalysisResponse>> analyzeWithResult(
    String markdownData, {
    String tone = 'gentle',
  }) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/analyze');

      // 백엔드로 요청
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': markdownData,
          'language': language,
          'tone': tone,
        }),
      ).timeout(AppConstants.apiTimeout);

      // 성공
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return Result.success(AiAnalysisResponse.fromJson(jsonResponse));
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
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/analyze');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': markdownData,
          'language': language,
          'tone': tone,
        }),
      ).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return AiAnalysisResponse.fromJson(jsonResponse);
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
