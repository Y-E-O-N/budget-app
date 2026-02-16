// =============================================================================
// import_service.dart - 엑셀 불러오기 서비스
// =============================================================================
import 'dart:math';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../utils/result.dart';
import '../constants/error_messages.dart';

// =============================================================================
// 보안 상수 정의
// =============================================================================
class ImportSecurityConstants {
  // 파일 크기 제한 (10MB)
  static const int maxFileSizeBytes = 10 * 1024 * 1024;
  // 시트당 최대 행 수
  static const int maxRowsPerSheet = 10000;
  // 이름 최대 길이
  static const int maxNameLength = 100;
  // 금액 최대값 (100억)
  static const int maxAmount = 10000000000;
  // 엑셀 매직 바이트 (xlsx = PK zip)
  static const List<int> xlsxMagicBytes = [0x50, 0x4B, 0x03, 0x04];
  // xls 매직 바이트 (compound document)
  static const List<int> xlsMagicBytes = [0xD0, 0xCF, 0x11, 0xE0];
}

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

      // 보안 검증: 파일 크기 확인
      if (file.bytes!.length > ImportSecurityConstants.maxFileSizeBytes) {
        return Result.failure(AppException.file(
          messageKey: 'fileTooLarge',
          details: '${ImportSecurityConstants.maxFileSizeBytes ~/ (1024 * 1024)}MB',
        ));
      }

      // 보안 검증: 매직 바이트 확인 (파일 형식 검증)
      if (!_isValidExcelFile(file.bytes!)) {
        return Result.failure(AppException.file(messageKey: 'invalidFileFormat'));
      }

      return parse(file.bytes!);
    } catch (e) {
      return Result.failure(AppException.file(
        messageKey: 'importError',
        originalError: e,
      ));
    }
  }

  /// 매직 바이트로 엑셀 파일 형식 검증
  bool _isValidExcelFile(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // xlsx (PK zip format)
    if (bytes[0] == ImportSecurityConstants.xlsxMagicBytes[0] &&
        bytes[1] == ImportSecurityConstants.xlsxMagicBytes[1] &&
        bytes[2] == ImportSecurityConstants.xlsxMagicBytes[2] &&
        bytes[3] == ImportSecurityConstants.xlsxMagicBytes[3]) {
      return true;
    }
    // xls (compound document format)
    if (bytes[0] == ImportSecurityConstants.xlsMagicBytes[0] &&
        bytes[1] == ImportSecurityConstants.xlsMagicBytes[1] &&
        bytes[2] == ImportSecurityConstants.xlsMagicBytes[2] &&
        bytes[3] == ImportSecurityConstants.xlsMagicBytes[3]) {
      return true;
    }
    return false;
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
    final maxRows = min(sheet.maxRows, ImportSecurityConstants.maxRowsPerSheet);
    for (var i = 1; i < maxRows; i++) {
      final row = sheet.row(i);
      if (row.isEmpty) continue;

      final nameCell = row[0];
      final amountCell = row.length > 1 ? row[1] : null;

      if (nameCell == null || nameCell.value == null) continue;

      // 보안: 이름 길이 제한 적용
      final name = _sanitizeName(_getCellString(nameCell));
      // "합계", "Total", "合計" 행 제외
      if (_isTotalRow(name)) continue;

      // 보안: 금액 상한 적용
      final amount = amountCell != null ? _parseCurrencySafe(_getCellString(amountCell)) : 0;

      if (name.isNotEmpty && amount > 0) {
        budgets.add(ImportedBudget(name: name, amount: amount));
      }
    }
  }

  // 보안: 이름 길이 제한 및 정제
  String _sanitizeName(String name) {
    if (name.length > ImportSecurityConstants.maxNameLength) {
      return name.substring(0, ImportSecurityConstants.maxNameLength);
    }
    return name.trim();
  }

  // 보안: 금액 파싱 (상한 적용)
  int _parseCurrencySafe(String value) {
    final amount = _parseCurrency(value);
    if (amount > ImportSecurityConstants.maxAmount) {
      return ImportSecurityConstants.maxAmount;
    }
    if (amount < 0) return 0;  // 음수 방지
    return amount;
  }

  // 세부예산 시트 파싱
  void _parseSubBudgetSheet(Sheet sheet, List<ImportedSubBudget> subBudgets) {
    final maxRows = min(sheet.maxRows, ImportSecurityConstants.maxRowsPerSheet);
    for (var i = 1; i < maxRows; i++) {
      final row = sheet.row(i);
      if (row.length < 3) continue;

      final budgetNameCell = row[0];
      final subNameCell = row[1];
      final amountCell = row[2];

      if (budgetNameCell == null || subNameCell == null) continue;

      // 보안: 이름 길이 제한 적용
      final budgetName = _sanitizeName(_getCellString(budgetNameCell));
      final subName = _sanitizeName(_getCellString(subNameCell));
      // 보안: 금액 상한 적용
      final amount = _parseCurrencySafe(_getCellString(amountCell));

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
    final maxRows = min(sheet.maxRows, ImportSecurityConstants.maxRowsPerSheet);
    for (var i = 1; i < maxRows; i++) {
      final row = sheet.row(i);
      if (row.length < 5) continue;

      final dateCell = row[0];
      final budgetNameCell = row[1];
      final subBudgetNameCell = row[2];
      final memoCell = row[3];
      final amountCell = row[4];

      if (dateCell == null || budgetNameCell == null || amountCell == null) continue;

      final date = _parseDate(_getCellString(dateCell));
      // 보안: 이름 및 메모 길이 제한 적용
      final budgetName = _sanitizeName(_getCellString(budgetNameCell));
      final subBudgetName = _sanitizeName(_getCellString(subBudgetNameCell));
      final memo = _sanitizeName(_getCellString(memoCell));
      // 보안: 금액 상한 적용
      final amount = _parseCurrencySafe(_getCellString(amountCell));

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
