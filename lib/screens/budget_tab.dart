import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_localizations.dart';
import '../providers/budget_provider.dart';
import '../providers/settings_provider.dart';
import '../models/budget.dart';
import 'budget_detail_screen.dart';

// 천 단위 콤마 포맷터
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('#,###', 'ko_KR');
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final numericString = newValue.text.replaceAll(',', '');
    if (numericString.isEmpty || int.tryParse(numericString) == null) return oldValue;
    final formatted = _formatter.format(int.parse(numericString));
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

// =============================================================================
// 스프레드시트 스타일 상수
// =============================================================================
class _SheetStyle {
  static const double borderWidth = 1.0;  // 실선 두께
  static const double cellPaddingH = 8.0;  // 셀 가로 패딩
  static const double cellPaddingV = 10.0;  // 셀 세로 패딩
  static const double fontSize = 13.0;  // 기본 폰트 크기
  static const double headerFontSize = 12.0;  // 헤더 폰트 크기

  // 셀 테두리 색상
  static Color borderColor(BuildContext context) =>
    Theme.of(context).dividerColor.withValues(alpha: 0.5);

  // 헤더 배경색
  static Color headerBg(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHighest;

  // 짝수 행 배경색
  static Color evenRowBg(BuildContext context) =>
    Theme.of(context).colorScheme.surface;

  // 홀수 행 배경색
  static Color oddRowBg(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerLowest;
}

class BudgetTab extends StatelessWidget {
  const BudgetTab({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Consumer2<BudgetProvider, SettingsProvider>(
      builder: (context, provider, settings, child) {
        final budgets = provider.currentBudgets;
        final totalBudget = provider.totalBudget;
        int totalExpense = 0;
        for (var b in budgets) { totalExpense += provider.getTotalExpense(b.id); }
        final totalRemaining = totalBudget - totalExpense;

        return Scaffold(
          appBar: AppBar(
            title: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => provider.previousMonth()),
              Text('${provider.currentYear}. ${provider.currentMonth}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => provider.nextMonth()),
            ]),
            actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddBudgetDialog(context))],
          ),
          body: Column(
            children: [
              // 요약 테이블 (스프레드시트 스타일)
              _buildSummaryTable(context, loc, totalBudget, totalExpense, totalRemaining),
              const SizedBox(height: 8),
              // 메인 테이블
              Expanded(
                child: budgets.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.table_chart_outlined, size: 64, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(loc.tr('addBudgetPlease'), style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.7))),
                      ]))
                    : _buildDataTable(context, loc, budgets, provider),
              ),
            ],
          ),
        );
      },
    );
  }

  // 요약 테이블 (상단)
  Widget _buildSummaryTable(BuildContext context, AppLocalizations loc, int totalBudget, int totalExpense, int totalRemaining) {
    final border = BorderSide(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth);

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      decoration: BoxDecoration(
        border: Border.all(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth),
      ),
      child: Table(
        border: TableBorder(
          horizontalInside: border,
          verticalInside: border,
        ),
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
        },
        children: [
          // 헤더 행
          TableRow(
            decoration: BoxDecoration(color: _SheetStyle.headerBg(context)),
            children: [
              _buildCell(loc.tr('budget'), isHeader: true, context: context),
              _buildCell(loc.tr('used'), isHeader: true, context: context),
              _buildCell(loc.tr('remaining'), isHeader: true, context: context),
            ],
          ),
          // 데이터 행
          TableRow(
            decoration: BoxDecoration(color: _SheetStyle.evenRowBg(context)),
            children: [
              _buildCell(context.formatCurrency(totalBudget), context: context, align: TextAlign.right),
              _buildCell(context.formatCurrency(totalExpense), context: context, align: TextAlign.right),
              _buildCell(
                context.formatCurrency(totalRemaining),
                context: context,
                align: TextAlign.right,
                textColor: totalRemaining < 0 ? Theme.of(context).colorScheme.error : null,
                bold: totalRemaining < 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 데이터 테이블 (메인)
  Widget _buildDataTable(BuildContext context, AppLocalizations loc, List<Budget> budgets, BudgetProvider provider) {
    final border = BorderSide(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth),
      ),
      child: Column(
        children: [
          // 헤더 행
          Table(
            border: TableBorder(verticalInside: border),
            columnWidths: const {
              0: FlexColumnWidth(2.5),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
              4: FixedColumnWidth(32),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: _SheetStyle.headerBg(context)),
                children: [
                  _buildCell(loc.tr('budgetName'), isHeader: true, context: context),
                  _buildCell(loc.tr('budget'), isHeader: true, context: context, align: TextAlign.right),
                  _buildCell(loc.tr('used'), isHeader: true, context: context, align: TextAlign.right),
                  _buildCell(loc.tr('remaining'), isHeader: true, context: context, align: TextAlign.right),
                  _buildCell('', isHeader: true, context: context),  // 화살표 열
                ],
              ),
            ],
          ),
          // 데이터 행들
          Expanded(
            child: ListView.builder(
              itemCount: budgets.length,
              itemBuilder: (context, index) {
                final budget = budgets[index];
                final expense = provider.getTotalExpense(budget.id);
                final remaining = budget.amount - expense;
                return _BudgetRow(
                  budget: budget,
                  expense: expense,
                  remaining: remaining,
                  isEven: index % 2 == 0,
                  isLast: index == budgets.length - 1,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 셀 위젯
  Widget _buildCell(String text, {
    required BuildContext context,
    bool isHeader = false,
    TextAlign align = TextAlign.left,
    Color? textColor,
    bool bold = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _SheetStyle.cellPaddingH,
        vertical: _SheetStyle.cellPaddingV,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? _SheetStyle.headerFontSize : _SheetStyle.fontSize,
          fontWeight: isHeader || bold ? FontWeight.w600 : FontWeight.normal,
          color: textColor ?? (isHeader
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : Theme.of(context).colorScheme.onSurface),
        ),
        textAlign: align,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _showAddBudgetDialog(BuildContext context) {
    final loc = context.loc;
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    bool isRecurring = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(loc.tr('addBudget')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: loc.tr('budgetName'), hintText: loc.tr('budgetNameHint'), border: const OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: InputDecoration(labelText: loc.tr('amount'), hintText: '0', suffixText: context.currency, border: const OutlineInputBorder(), errorText: errorMessage),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
              onChanged: (value) { if (errorMessage != null) setState(() => errorMessage = null); },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(title: Text(loc.tr('applyMonthly')), subtitle: Text(loc.tr('applyMonthlyDesc')), value: isRecurring, onChanged: (value) => setState(() => isRecurring = value ?? false), contentPadding: EdgeInsets.zero),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.tr('cancel'))),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final amount = int.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
                if (name.isEmpty) return;
                if (amount <= 0) { setState(() => errorMessage = loc.tr('numberOnlyError')); return; }
                context.read<BudgetProvider>().addBudget(name, amount, isRecurring);
                Navigator.pop(context);
              },
              child: Text(loc.tr('add')),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 예산 행 위젯 (스프레드시트 스타일)
// =============================================================================
class _BudgetRow extends StatelessWidget {
  final Budget budget;
  final int expense;
  final int remaining;
  final bool isEven;
  final bool isLast;

  const _BudgetRow({
    required this.budget,
    required this.expense,
    required this.remaining,
    required this.isEven,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final border = BorderSide(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth);

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BudgetDetailScreen(budget: budget))),
      onLongPress: () => _showEditDeleteMenu(context),
      child: Table(
        border: TableBorder(
          verticalInside: border,
          bottom: isLast ? BorderSide.none : border,
        ),
        columnWidths: const {
          0: FlexColumnWidth(2.5),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(2),
          3: FlexColumnWidth(2),
          4: FixedColumnWidth(32),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: isEven ? _SheetStyle.evenRowBg(context) : _SheetStyle.oddRowBg(context),
            ),
            children: [
              // 예산명 + 반복 아이콘
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _SheetStyle.cellPaddingH,
                  vertical: _SheetStyle.cellPaddingV,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        budget.name,
                        style: TextStyle(fontSize: _SheetStyle.fontSize),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (budget.isRecurring)
                      Icon(Icons.repeat, size: 14, color: Theme.of(context).colorScheme.primary),
                  ],
                ),
              ),
              // 예산액
              _buildDataCell(context.formatCurrency(budget.amount), context),
              // 사용액
              _buildDataCell(context.formatCurrency(expense), context),
              // 잔액
              _buildDataCell(
                context.formatCurrency(remaining),
                context,
                textColor: remaining < 0 ? Theme.of(context).colorScheme.error : null,
                bold: remaining < 0,
              ),
              // 화살표
              Container(
                padding: EdgeInsets.symmetric(vertical: _SheetStyle.cellPaddingV),
                child: Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataCell(String text, BuildContext context, {Color? textColor, bool bold = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _SheetStyle.cellPaddingH,
        vertical: _SheetStyle.cellPaddingV,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: _SheetStyle.fontSize,
          color: textColor,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        ),
        textAlign: TextAlign.right,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _showEditDeleteMenu(BuildContext context) {
    final loc = context.loc;
    showModalBottomSheet(context: context, builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.edit), title: Text(loc.tr('edit')), onTap: () { Navigator.pop(context); _showEditDialog(context); }),
        ListTile(leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error), title: Text(loc.tr('delete'), style: TextStyle(color: Theme.of(context).colorScheme.error)), onTap: () { Navigator.pop(context); _confirmDelete(context); }),
      ]),
    ));
  }

  void _showEditDialog(BuildContext context) {
    final loc = context.loc;
    final nameController = TextEditingController(text: budget.name);
    final amountController = TextEditingController(text: NumberFormat('#,###', 'ko_KR').format(budget.amount));
    bool isRecurring = budget.isRecurring;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(loc.tr('editBudget')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: loc.tr('budgetName'), border: const OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: InputDecoration(labelText: loc.tr('amount'), suffixText: context.currency, border: const OutlineInputBorder(), errorText: errorMessage),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
              onChanged: (value) { if (errorMessage != null) setState(() => errorMessage = null); },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(title: Text(loc.tr('applyMonthly')), value: isRecurring, onChanged: (value) => setState(() => isRecurring = value ?? false), contentPadding: EdgeInsets.zero),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.tr('cancel'))),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final amount = int.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
                if (name.isEmpty) return;
                if (amount <= 0) { setState(() => errorMessage = loc.tr('numberOnlyError')); return; }
                context.read<BudgetProvider>().updateBudget(budget.copyWith(name: name, amount: amount, isRecurring: isRecurring));
                Navigator.pop(context);
              },
              child: Text(loc.tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final loc = context.loc;
    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text(loc.tr('deleteConfirm')),
      content: Text("'${budget.name}'"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.tr('cancel'))),
        FilledButton(onPressed: () { context.read<BudgetProvider>().deleteBudget(budget.id); Navigator.pop(context); }, style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), child: Text(loc.tr('delete'))),
      ],
    ));
  }
}
