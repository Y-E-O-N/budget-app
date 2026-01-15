// =============================================================================
// export_service.dart - 엑셀 내보내기 서비스
// =============================================================================
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../models/sub_budget.dart';
import '../models/expense.dart';
import '../app_localizations.dart';

class ExportService {
  final String language;
  final String currency;
  late AppLocalizations _loc;
  final _currencyFormat = NumberFormat('#,###', 'ko_KR');

  ExportService({required this.language, required this.currency}) {
    _loc = AppLocalizations(language);
  }

  // 통화 포맷
  String _formatCurrency(int amount) {
    final formatted = _currencyFormat.format(amount);
    if (currency == '₩') return '$formatted원';
    if (currency == '¥') return '$formatted$currency';
    return '$currency$formatted';
  }

  // 퍼센트 계산
  String _calcPercent(int used, int total) {
    if (total == 0) return '0%';
    return '${(used / total * 100).toStringAsFixed(1)}%';
  }

  // 엑셀 파일 생성 및 다운로드
  Future<bool> exportToExcel({
    required List<Budget> budgets,
    required List<SubBudget> subBudgets,
    required List<Expense> expenses,
    required int year,
    required int month,
    required int Function(String budgetId) getTotalExpense,
    required int Function(String subBudgetId) getSubBudgetExpense,
  }) async {
    try {
      final excel = Excel.createExcel();

      // 시트 생성
      _createSummarySheet(excel, budgets, getTotalExpense);
      _createSubBudgetSheet(excel, budgets, subBudgets, getSubBudgetExpense);
      _createExpenseSheet(excel, budgets, subBudgets, expenses);

      // 기본 시트 삭제
      excel.delete('Sheet1');

      // 파일명 생성
      final fileName = '${_loc.tr('appTitle')}_${year}_$month.xlsx';

      // 파일 저장
      final bytes = excel.save();
      if (bytes != null) {
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: Uint8List.fromList(bytes),
          mimeType: MimeType.microsoftExcel,
        );
        return true;
      }
      return false;
    } catch (_) {
      // 내보내기 실패 시 false 반환
      return false;
    }
  }

  // 시트1: 요약
  void _createSummarySheet(Excel excel, List<Budget> budgets, int Function(String) getTotalExpense) {
    final sheet = excel[_loc.tr('budget')];

    // 헤더 스타일
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
      horizontalAlign: HorizontalAlign.Center,
    );

    // 헤더
    final headers = [_loc.tr('budgetName'), _loc.tr('budget'), _loc.tr('used'), _loc.tr('remaining'), _getPercentHeader()];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // 데이터
    int totalBudget = 0;
    int totalExpense = 0;

    for (var i = 0; i < budgets.length; i++) {
      final budget = budgets[i];
      final expense = getTotalExpense(budget.id);
      final remaining = budget.amount - expense;

      totalBudget += budget.amount;
      totalExpense += expense;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value = TextCellValue(budget.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value = TextCellValue(_formatCurrency(budget.amount));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value = TextCellValue(_formatCurrency(expense));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1)).value = TextCellValue(_formatCurrency(remaining));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1)).value = TextCellValue(_calcPercent(expense, budget.amount));
    }

    // 합계 행
    final totalRow = budgets.length + 1;
    final totalStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#FFF3E0'));

    final totalRemaining = totalBudget - totalExpense;
    final totalCells = [
      _getTotalLabel(),
      _formatCurrency(totalBudget),
      _formatCurrency(totalExpense),
      _formatCurrency(totalRemaining),
      _calcPercent(totalExpense, totalBudget),
    ];

    for (var i = 0; i < totalCells.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: totalRow));
      cell.value = TextCellValue(totalCells[i]);
      cell.cellStyle = totalStyle;
    }

    // 열 너비 설정
    sheet.setColumnWidth(0, 20);
    sheet.setColumnWidth(1, 15);
    sheet.setColumnWidth(2, 15);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 10);
  }

  // 시트2: 세부예산별 요약
  void _createSubBudgetSheet(Excel excel, List<Budget> budgets, List<SubBudget> subBudgets, int Function(String) getSubBudgetExpense) {
    final sheet = excel[_loc.tr('subBudget')];

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
      horizontalAlign: HorizontalAlign.Center,
    );

    // 헤더
    final headers = [_loc.tr('budget'), _loc.tr('subBudget'), _loc.tr('budget'), _loc.tr('used'), _loc.tr('remaining')];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // 데이터
    var row = 1;
    for (var budget in budgets) {
      final subs = subBudgets.where((s) => s.budgetId == budget.id).toList();
      for (var sub in subs) {
        final expense = getSubBudgetExpense(sub.id);
        final remaining = sub.amount - expense;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(budget.name);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(sub.name);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue(_formatCurrency(sub.amount));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = TextCellValue(_formatCurrency(expense));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = TextCellValue(_formatCurrency(remaining));
        row++;
      }
    }

    // 열 너비 설정
    sheet.setColumnWidth(0, 15);
    sheet.setColumnWidth(1, 15);
    sheet.setColumnWidth(2, 15);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 15);
  }

  // 시트3: 지출 내역
  void _createExpenseSheet(Excel excel, List<Budget> budgets, List<SubBudget> subBudgets, List<Expense> expenses) {
    final sheet = excel[_loc.tr('expenseHistory')];

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
      horizontalAlign: HorizontalAlign.Center,
    );

    // 헤더
    final headers = [_loc.tr('date'), _loc.tr('budget'), _loc.tr('subBudget'), _loc.tr('memo'), _loc.tr('amount')];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // 날짜순 정렬
    final sortedExpenses = List<Expense>.from(expenses)..sort((a, b) => a.date.compareTo(b.date));

    // 데이터
    for (var i = 0; i < sortedExpenses.length; i++) {
      final exp = sortedExpenses[i];
      final budget = budgets.where((b) => b.id == exp.budgetId).firstOrNull;
      final subBudget = exp.subBudgetId != null ? subBudgets.where((s) => s.id == exp.subBudgetId).firstOrNull : null;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value = TextCellValue(DateFormat('yyyy-MM-dd').format(exp.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value = TextCellValue(budget?.name ?? '-');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value = TextCellValue(subBudget?.name ?? '-');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1)).value = TextCellValue(exp.memo ?? '-');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1)).value = TextCellValue(_formatCurrency(exp.amount));
    }

    // 열 너비 설정
    sheet.setColumnWidth(0, 12);
    sheet.setColumnWidth(1, 15);
    sheet.setColumnWidth(2, 15);
    sheet.setColumnWidth(3, 25);
    sheet.setColumnWidth(4, 15);
  }

  String _getPercentHeader() {
    switch (language) {
      case 'en': return 'Usage %';
      case 'ja': return '使用率';
      default: return '사용률';
    }
  }

  String _getTotalLabel() {
    switch (language) {
      case 'en': return 'Total';
      case 'ja': return '合計';
      default: return '합계';
    }
  }
}
