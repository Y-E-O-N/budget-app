// =============================================================================
// analysis_provider.dart - AI 분석 상태 관리 Provider
// =============================================================================
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/ai_analysis_service.dart';
import '../services/markdown_export_service.dart';
import '../models/budget.dart';
import '../models/sub_budget.dart';
import '../models/expense.dart';

// 분석 상태
enum AnalysisStatus {
  idle,       // 대기 중
  running,    // 분석 중
  completed,  // 완료
  cancelled,  // 취소됨
  error,      // 에러
}

// 분석 결과 기록 (이력 저장용)
class AnalysisRecord {
  final DateTime analyzedAt;      // 분석 시점
  final DateTime startDate;       // 분석 기간 시작
  final DateTime endDate;         // 분석 기간 종료
  final String tone;              // 응답 톤
  final AiAnalysisResponse result;

  AnalysisRecord({
    required this.analyzedAt,
    required this.startDate,
    required this.endDate,
    required this.tone,
    required this.result,
  });

  // JSON 직렬화 (#13, #17: 새 필드 추가)
  Map<String, dynamic> toJson() => {
    'analyzedAt': analyzedAt.toIso8601String(),
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'tone': tone,
    'result': {
      'oneLiner': result.oneLiner,
      'summary': result.summary,
      'insights': result.insights,
      'warnings': result.warnings,
      'suggestions': result.suggestions,
      'spendingPlan': result.spendingPlan,  // #13: 잔여 기간 지출 계획
      'remainingAnalyses': result.remainingAnalyses,  // #17: 남은 분석 횟수
      'pattern': {
        'mainCategory': result.pattern.mainCategory,
        'spendingTrend': result.pattern.spendingTrend,
        'savingPotential': result.pattern.savingPotential,
        'riskLevel': result.pattern.riskLevel,
      },
    },
  };

  // JSON 역직렬화
  factory AnalysisRecord.fromJson(Map<String, dynamic> json) {
    final resultJson = json['result'] as Map<String, dynamic>;
    return AnalysisRecord(
      analyzedAt: DateTime.parse(json['analyzedAt']),
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      tone: json['tone'] ?? 'gentle',  // 기본값: gentle
      result: AiAnalysisResponse.fromJson(resultJson),
    );
  }
}

class AnalysisProvider extends ChangeNotifier {
  AnalysisStatus _status = AnalysisStatus.idle;
  AnalysisRecord? _currentRecord;  // 현재/최신 분석 결과
  List<AnalysisRecord> _history = [];  // 분석 이력
  String? _error;
  bool _hasUnreadResult = false;
  Completer<void>? _cancelCompleter;
  Box? _historyBox;

  // 현재 분석 중인 기간 (진행 중 표시용)
  DateTime? _currentStartDate;
  DateTime? _currentEndDate;

  // Getters
  AnalysisStatus get status => _status;
  AnalysisRecord? get currentRecord => _currentRecord;
  AiAnalysisResponse? get result => _currentRecord?.result;
  List<AnalysisRecord> get history => _history;
  String? get error => _error;
  bool get hasUnreadResult => _hasUnreadResult;
  bool get isRunning => _status == AnalysisStatus.running;
  DateTime? get currentStartDate => _currentStartDate;
  DateTime? get currentEndDate => _currentEndDate;

  // 초기화 (Hive에서 이력 로드)
  Future<void> init() async {
    _historyBox = await Hive.openBox('analysisHistory');
    _loadHistory();
  }

  // 이력 로드
  void _loadHistory() {
    final historyJson = _historyBox?.get('history');
    if (historyJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(historyJson);
        _history = decoded.map((e) => AnalysisRecord.fromJson(e)).toList();
        // 최신 기록을 현재 기록으로 설정
        if (_history.isNotEmpty) {
          _currentRecord = _history.first;
        }
      } catch (e) {
        _history = [];
      }
    }
    notifyListeners();
  }

  // 이력 저장
  Future<void> _saveHistory() async {
    final historyJson = jsonEncode(_history.map((e) => e.toJson()).toList());
    await _historyBox?.put('history', historyJson);
  }

  // 분석 시작
  Future<void> startAnalysis({
    required String language,
    required String currency,
    required List<Budget> budgets,
    required List<SubBudget> subBudgets,
    required List<Expense> expenses,
    required DateTime startDate,
    required DateTime endDate,
    required int Function(String) getTotalExpense,
    required int Function(String) getSubBudgetExpense,
    String tone = 'gentle',  // 응답 톤 파라미터 추가
  }) async {
    // 이미 실행 중이면 무시
    if (_status == AnalysisStatus.running) return;

    // 상태 초기화
    _status = AnalysisStatus.running;
    _error = null;
    _hasUnreadResult = false;
    _cancelCompleter = Completer<void>();
    _currentStartDate = startDate;
    _currentEndDate = endDate;
    notifyListeners();

    try {
      // 마크다운 데이터 생성
      final mdService = MarkdownExportService(
        language: language,
        currency: currency,
      );

      final markdownData = mdService.generateMarkdown(
        budgets: budgets,
        subBudgets: subBudgets,
        expenses: expenses,
        startDate: startDate,
        endDate: endDate,
        getTotalExpense: getTotalExpense,
        getSubBudgetExpense: getSubBudgetExpense,
      );

      // AI 분석 요청
      final aiService = AiAnalysisService(language: language);

      // 취소와 분석 동시 진행 (analyzeWithResult 사용)
      final analysisResult = await Future.any([
        aiService.analyzeWithResult(markdownData, tone: tone),
        _cancelCompleter!.future.then((_) => throw CancelledException()),
      ]);

      // Result 패턴으로 결과 처리
      analysisResult.fold(
        onSuccess: (response) async {
          _status = AnalysisStatus.completed;

          // 분석 기록 생성
          final record = AnalysisRecord(
            analyzedAt: DateTime.now(),
            startDate: startDate,
            endDate: endDate,
            tone: tone,
            result: response,
          );

          _currentRecord = record;
          _hasUnreadResult = true;

          // 이력에 추가 (최신이 앞에 오도록)
          _history.insert(0, record);

          // 이력은 최대 20개만 유지
          if (_history.length > 20) {
            _history = _history.sublist(0, 20);
          }

          // 저장
          await _saveHistory();
        },
        onFailure: (error) {
          _status = AnalysisStatus.error;
          _error = aiService.getErrorMessage(error);
        },
      );
    } on CancelledException {
      _status = AnalysisStatus.cancelled;
    } catch (e) {
      _status = AnalysisStatus.error;
      _error = e.toString();
    }

    _currentStartDate = null;
    _currentEndDate = null;
    notifyListeners();
  }

  // 분석 취소
  void cancelAnalysis() {
    if (_status == AnalysisStatus.running && _cancelCompleter != null && !_cancelCompleter!.isCompleted) {
      _cancelCompleter!.complete();
    }
  }

  // 결과 읽음 처리
  void markResultAsRead() {
    _hasUnreadResult = false;
    notifyListeners();
  }

  // 특정 이력 선택 (현재 기록으로 설정)
  void selectRecord(AnalysisRecord record) {
    _currentRecord = record;
    notifyListeners();
  }

  // 이력 삭제
  Future<void> deleteRecord(AnalysisRecord record) async {
    _history.remove(record);
    if (_currentRecord == record) {
      _currentRecord = _history.isNotEmpty ? _history.first : null;
    }
    await _saveHistory();
    notifyListeners();
  }

  // 전체 이력 삭제
  Future<void> clearHistory() async {
    _history.clear();
    _currentRecord = null;
    await _saveHistory();
    notifyListeners();
  }

  // 상태 초기화
  void reset() {
    _status = AnalysisStatus.idle;
    _error = null;
    _hasUnreadResult = false;
    notifyListeners();
  }
}

// 취소 예외
class CancelledException implements Exception {}
