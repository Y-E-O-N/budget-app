// =============================================================================
// import_service.dart - 엑셀 불러오기 서비스
// =============================================================================
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../utils/result.dart';
import '../constants/error_messages.dart';

// 불러오기 결과 데이터
class ImportData {
  final List<ImportedBudget> budgets;
  final List<ImportedSubBudget> subBudgets;
  final List<ImportedExpense> expenses;

  const ImportData({
    required this.budgets,
    required this.subBudgets,
    required this.expenses,
  });
}

// 기존 호환용 ImportResult (deprecated, 추후 제거)
@Deprecated('Use Result<ImportData> instead')
class ImportResult {
  final bool success;
  final String? error;
  final List<ImportedBudget> budgets;
  final List<ImportedSubBudget> subBudgets;
  final List<ImportedExpense> expenses;

  ImportResult({
    required this.success,
    this.error,
    this.budgets = const [],
    this.subBudgets = const [],
    this.expenses = const [],
  });

  factory ImportResult.error(String message) {
    return ImportResult(success: false, error: message);
  }

  factory ImportResult.success({
    required List<ImportedBudget> budgets,
    required List<ImportedSubBudget> subBudgets,
    required List<ImportedExpense> expenses,
  }) {
    return ImportResult(
      success: true,
      budgets: budgets,
      subBudgets: subBudgets,
      expenses: expenses,
    );
  }

  // Result<ImportData>로 변환
  Result<ImportData> toResult() {
    if (success) {
      return Result.success(ImportData(
        budgets: budgets,
        subBudgets: subBudgets,
        expenses: expenses,
      ));
    }
    return Result.failure(AppException.file(
      messageKey: 'importError',
      details: error,
    ));
  }
}

// 불러온 예산 데이터
class ImportedBudget {
  final String name;
  final int amount;

  ImportedBudget({required this.name, required this.amount});
}

// 불러온 세부예산 데이터
class ImportedSubBudget {
  final String budgetName;
  final String name;
  final int amount;

  ImportedSubBudget({required this.budgetName, required this.name, required this.amount});
}

// 불러온 지출 데이터
class ImportedExpense {
  final DateTime date;
  final String budgetName;
  final String? subBudgetName;
  final String? memo;
  final int amount;

  ImportedExpense({
    required this.date,
    required this.budgetName,
    this.subBudgetName,
    this.memo,
    required this.amount,
  });
}

class ImportService {
  final String language;

  ImportService({required this.language});

  // ==========================================================================
  // 새로운 Result 기반 메서드 (권장)
  // ==========================================================================

  /// 파일 선택 및 파싱 (Result 버전)
  Future<Result<ImportData>> pickAndParse() async {
    try {
      // 파일 선택
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      // 파일 선택 취소
      if (result == null || result.files.isEmpty) {
        return Result.failure(AppException.file(messageKey: 'noFileSelected'));
      }

      final file = result.files.first;
      // 파일 읽기 실패
      if (file.bytes == null) {
        return Result.failure(AppException.file(messageKey: 'fileReadError'));
      }

      return parse(file.bytes!);
    } catch (e) {
      return Result.failure(AppException.file(
        messageKey: 'importError',
        originalError: e,
      ));
    }
  }

  /// 엑셀 파일 파싱 (Result 버전)
  Result<ImportData> parse(Uint8List bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);
      final sheetNames = excel.tables.keys.toList();

      // 시트 이름 찾기
      final budgetSheetName = _findSheetName(sheetNames, ['예산', 'Budget', '予算']);
      final subBudgetSheetName = _findSheetName(sheetNames, ['세부예산', 'Sub-budget', 'サブ予算']);
      final expenseSheetName = _findSheetName(sheetNames, ['지출 내역', '지출내역', 'Expenses', '支出履歴']);

      // 유효한 시트가 없으면 에러
      if (budgetSheetName == null && expenseSheetName == null) {
        return Result.failure(AppException.file(messageKey: 'invalidExcelFormat'));
      }

      final budgets = <ImportedBudget>[];
      final subBudgets = <ImportedSubBudget>[];
      final expenses = <ImportedExpense>[];

      // 시트별 파싱
      if (budgetSheetName != null) {
        _parseBudgetSheet(excel.tables[budgetSheetName]!, budgets);
      }
      if (subBudgetSheetName != null) {
        _parseSubBudgetSheet(excel.tables[subBudgetSheetName]!, subBudgets);
      }
      if (expenseSheetName != null) {
        _parseExpenseSheet(excel.tables[expenseSheetName]!, expenses, budgets, subBudgets);
      }

      return Result.success(ImportData(
        budgets: budgets,
        subBudgets: subBudgets,
        expenses: expenses,
      ));
    } catch (e) {
      return Result.failure(AppException.parse(originalError: e));
    }
  }

  /// 에러 메시지 가져오기 (중앙화된 메시지 사용)
  String getErrorMessage(AppException error) {
    return ErrorMessages.getWithDetails(error.messageKey, language, error.details);
  }

  // ==========================================================================
  // 기존 호환용 메서드 (deprecated)
  // ==========================================================================

  @Deprecated('Use pickAndParse() instead')
  Future<ImportResult> pickAndParseExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult.error(_getErrorMessage('noFileSelected'));
      }

      final file = result.files.first;
      if (file.bytes == null) {
        return ImportResult.error(_getErrorMessage('fileReadError'));
      }

      return parseExcel(file.bytes!);
    } catch (e) {
      return ImportResult.error('${_getErrorMessage('importError')}: $e');
    }
  }

  @Deprecated('Use parse() instead')
  ImportResult parseExcel(Uint8List bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);
      final sheetNames = excel.tables.keys.toList();

      final budgetSheetName = _findSheetName(sheetNames, ['예산', 'Budget', '予算']);
      final subBudgetSheetName = _findSheetName(sheetNames, ['세부예산', 'Sub-budget', 'サブ予算']);
      final expenseSheetName = _findSheetName(sheetNames, ['지출 내역', '지출내역', 'Expenses', '支出履歴']);

      if (budgetSheetName == null && expenseSheetName == null) {
        return ImportResult.error(_getErrorMessage('invalidFormat'));
      }

      final budgets = <ImportedBudget>[];
      final subBudgets = <ImportedSubBudget>[];
      final expenses = <ImportedExpense>[];

      if (budgetSheetName != null) {
        _parseBudgetSheet(excel.tables[budgetSheetName]!, budgets);
      }
      if (subBudgetSheetName != null) {
        _parseSubBudgetSheet(excel.tables[subBudgetSheetName]!, subBudgets);
      }
      if (expenseSheetName != null) {
        _parseExpenseSheet(excel.tables[expenseSheetName]!, expenses, budgets, subBudgets);
      }

      return ImportResult.success(
        budgets: budgets,
        subBudgets: subBudgets,
        expenses: expenses,
      );
    } catch (e) {
      return ImportResult.error('${_getErrorMessage('parseError')}: $e');
    }
  }

  // 시트 이름 찾기 (다국어)
  String? _findSheetName(List<String> sheetNames, List<String> candidates) {
    for (final name in sheetNames) {
      for (final candidate in candidates) {
        if (name.toLowerCase().contains(candidate.toLowerCase())) {
          return name;
        }
      }
    }
    return null;
  }

  // 예산 시트 파싱
  void _parseBudgetSheet(Sheet sheet, List<ImportedBudget> budgets) {
    for (var i = 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.isEmpty) continue;

      final nameCell = row[0];
      final amountCell = row.length > 1 ? row[1] : null;

      if (nameCell == null || nameCell.value == null) continue;

      final name = _getCellString(nameCell);
      // "합계", "Total", "合計" 행 제외
      if (_isTotalRow(name)) continue;

      final amount = amountCell != null ? _parseCurrency(_getCellString(amountCell)) : 0;

      if (name.isNotEmpty && amount > 0) {
        budgets.add(ImportedBudget(name: name, amount: amount));
      }
    }
  }

  // 세부예산 시트 파싱
  void _parseSubBudgetSheet(Sheet sheet, List<ImportedSubBudget> subBudgets) {
    for (var i = 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.length < 3) continue;

      final budgetNameCell = row[0];
      final subNameCell = row[1];
      final amountCell = row[2];

      if (budgetNameCell == null || subNameCell == null) continue;

      final budgetName = _getCellString(budgetNameCell);
      final subName = _getCellString(subNameCell);
      final amount = _parseCurrency(_getCellString(amountCell));

      if (budgetName.isNotEmpty && subName.isNotEmpty && amount > 0) {
        subBudgets.add(ImportedSubBudget(
          budgetName: budgetName,
          name: subName,
          amount: amount,
        ));
      }
    }
  }

  // 지출내역 시트 파싱
  void _parseExpenseSheet(
    Sheet sheet,
    List<ImportedExpense> expenses,
    List<ImportedBudget> budgets,
    List<ImportedSubBudget> subBudgets,
  ) {
    for (var i = 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.length < 5) continue;

      final dateCell = row[0];
      final budgetNameCell = row[1];
      final subBudgetNameCell = row[2];
      final memoCell = row[3];
      final amountCell = row[4];

      if (dateCell == null || budgetNameCell == null || amountCell == null) continue;

      final date = _parseDate(_getCellString(dateCell));
      final budgetName = _getCellString(budgetNameCell);
      final subBudgetName = _getCellString(subBudgetNameCell);
      final memo = _getCellString(memoCell);
      final amount = _parseCurrency(_getCellString(amountCell));

      if (date != null && budgetName.isNotEmpty && budgetName != '-' && amount > 0) {
        // 예산이 목록에 없으면 추가
        if (!budgets.any((b) => b.name == budgetName)) {
          budgets.add(ImportedBudget(name: budgetName, amount: 0));
        }

        // 세부예산이 있고 목록에 없으면 추가
        if (subBudgetName.isNotEmpty && subBudgetName != '-') {
          if (!subBudgets.any((s) => s.budgetName == budgetName && s.name == subBudgetName)) {
            subBudgets.add(ImportedSubBudget(
              budgetName: budgetName,
              name: subBudgetName,
              amount: 0,
            ));
          }
        }

        expenses.add(ImportedExpense(
          date: date,
          budgetName: budgetName,
          subBudgetName: subBudgetName.isNotEmpty && subBudgetName != '-' ? subBudgetName : null,
          memo: memo.isNotEmpty && memo != '-' ? memo : null,
          amount: amount,
        ));
      }
    }
  }

  // 셀 값을 문자열로 변환
  String _getCellString(Data? cell) {
    if (cell == null || cell.value == null) return '';
    final value = cell.value;
    if (value is TextCellValue) return value.value.toString();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is DateCellValue) {
      return DateFormat('yyyy-MM-dd').format(DateTime(value.year, value.month, value.day));
    }
    return value.toString();
  }

  // 통화 문자열을 숫자로 파싱
  int _parseCurrency(String value) {
    if (value.isEmpty) return 0;
    // 통화 기호 및 콤마 제거
    final cleaned = value
        .replaceAll(RegExp(r'[₩$¥€원]'), '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();
    return int.tryParse(cleaned) ?? 0;
  }

  // 날짜 문자열 파싱
  DateTime? _parseDate(String value) {
    if (value.isEmpty) return null;
    try {
      // yyyy-MM-dd 형식
      if (value.contains('-')) {
        return DateFormat('yyyy-MM-dd').parse(value);
      }
      // yyyy/MM/dd 형식
      if (value.contains('/')) {
        return DateFormat('yyyy/MM/dd').parse(value);
      }
      // yyyy.MM.dd 형식
      if (value.contains('.')) {
        return DateFormat('yyyy.MM.dd').parse(value);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 합계 행 확인
  bool _isTotalRow(String name) {
    final totals = ['합계', 'Total', '合計', 'total', 'TOTAL'];
    return totals.any((t) => name.contains(t));
  }

  // 에러 메시지
  String _getErrorMessage(String key) {
    final messages = {
      'ko': {
        'noFileSelected': '파일을 선택하지 않았습니다',
        'fileReadError': '파일을 읽을 수 없습니다',
        'importError': '불러오기 오류',
        'parseError': '파싱 오류',
        'invalidFormat': '올바른 엑셀 형식이 아닙니다',
      },
      'en': {
        'noFileSelected': 'No file selected',
        'fileReadError': 'Cannot read file',
        'importError': 'Import error',
        'parseError': 'Parse error',
        'invalidFormat': 'Invalid Excel format',
      },
      'ja': {
        'noFileSelected': 'ファイルが選択されていません',
        'fileReadError': 'ファイルを読み込めません',
        'importError': 'インポートエラー',
        'parseError': 'パースエラー',
        'invalidFormat': '無効なExcel形式です',
      },
    };
    return messages[language]?[key] ?? messages['ko']![key]!;
  }
}
