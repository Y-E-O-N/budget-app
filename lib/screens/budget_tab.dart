import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_localizations.dart';
import '../providers/budget_provider.dart';
import '../providers/settings_provider.dart';
import '../models/budget.dart';
import '../widgets/shared_styles.dart';
import 'budget_detail_screen.dart';

// #2: 예산 정렬 옵션 (#3: order 추가)
enum BudgetSortOption { order, name, nameDesc, amount, amountDesc, used, usedDesc, remaining, remainingDesc }

class BudgetTab extends StatefulWidget {
  const BudgetTab({super.key});

  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  BudgetSortOption _sortOption = BudgetSortOption.order;  // #3: 기본값을 순서로 변경

  // #2: 정렬된 예산 목록 반환 (#3: order 옵션 추가)
  List<Budget> _getSortedBudgets(List<Budget> budgets, BudgetProvider provider) {
    final sorted = List<Budget>.from(budgets);
    switch (_sortOption) {
      case BudgetSortOption.order:
        // #3: 이미 order로 정렬되어 있으므로 그대로 반환
        break;
      case BudgetSortOption.name:
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case BudgetSortOption.nameDesc:
        sorted.sort((a, b) => b.name.compareTo(a.name));
        break;
      case BudgetSortOption.amount:
        sorted.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case BudgetSortOption.amountDesc:
        sorted.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case BudgetSortOption.used:
        sorted.sort((a, b) => provider.getTotalExpense(a.id).compareTo(provider.getTotalExpense(b.id)));
        break;
      case BudgetSortOption.usedDesc:
        sorted.sort((a, b) => provider.getTotalExpense(b.id).compareTo(provider.getTotalExpense(a.id)));
        break;
      case BudgetSortOption.remaining:
        sorted.sort((a, b) => (a.amount - provider.getTotalExpense(a.id)).compareTo(b.amount - provider.getTotalExpense(b.id)));
        break;
      case BudgetSortOption.remainingDesc:
        sorted.sort((a, b) => (b.amount - provider.getTotalExpense(b.id)).compareTo(a.amount - provider.getTotalExpense(a.id)));
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Consumer2<BudgetProvider, SettingsProvider>(
      builder: (context, provider, settings, child) {
        final budgets = provider.currentBudgets;
        final sortedBudgets = _getSortedBudgets(budgets, provider);  // #2: 정렬 적용
        final totalBudget = provider.totalBudget;
        int totalExpense = 0;
        for (var b in budgets) { totalExpense += provider.getTotalExpense(b.id); }
        final totalRemaining = totalBudget - totalExpense;

        return Scaffold(
          appBar: AppBar(
            title: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => provider.previousMonth()),
              // #10: 날짜 터치시 월 선택 다이얼로그
              InkWell(
                onTap: () => _showMonthPickerDialog(context, provider),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text('${provider.currentYear}년 ${provider.currentMonth}월', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => provider.nextMonth()),
            ]),
            actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddBudgetDialog(context))],
          ),
          body: Column(
            children: [
              // 요약 테이블 (스프레드시트 스타일)
              _buildSummaryTable(context, loc, totalBudget, totalExpense, totalRemaining),
              const SizedBox(height: 8),
              // 메인 테이블 (#2: 정렬된 목록 사용)
              Expanded(
                child: sortedBudgets.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.table_chart_outlined, size: 64, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => _showAddBudgetDialog(context),
                          icon: const Icon(Icons.add),
                          label: Text(loc.tr('addFirstBudget')),
                        ),
                      ]))
                    : _buildDataTable(context, loc, sortedBudgets, provider),
              ),
            ],
          ),
        );
      },
    );
  }

  // 요약 테이블 (상단)
  Widget _buildSummaryTable(BuildContext context, AppLocalizations loc, int totalBudget, int totalExpense, int totalRemaining) {
    final border = BorderSide(color: SheetStyle.borderColor(context), width: SheetStyle.borderWidth);

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      decoration: BoxDecoration(
        border: Border.all(color: SheetStyle.borderColor(context), width: SheetStyle.borderWidth),
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
          // 헤더 행 (#19: 중앙 정렬)
          TableRow(
            decoration: BoxDecoration(color: SheetStyle.headerBg(context)),
            children: [
              _buildCell(loc.tr('budget'), isHeader: true, context: context, align: TextAlign.center),
              _buildCell(loc.tr('used'), isHeader: true, context: context, align: TextAlign.center),
              _buildCell(loc.tr('remaining'), isHeader: true, context: context, align: TextAlign.center),
            ],
          ),
          // 데이터 행
          TableRow(
            decoration: BoxDecoration(color: SheetStyle.evenRowBg(context)),
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
    final border = BorderSide(color: SheetStyle.borderColor(context), width: SheetStyle.borderWidth);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: SheetStyle.borderColor(context), width: SheetStyle.borderWidth),
      ),
      child: Column(
        children: [
          // 헤더 행 (#2: 정렬 기능 추가)
          Table(
            border: TableBorder(verticalInside: border, bottom: border),
            columnWidths: const {
              0: FlexColumnWidth(3),    // 예산명 너비 확장
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: SheetStyle.headerBg(context)),
                children: [
                  _buildSortableHeaderCell(loc.tr('budgetName'), BudgetSortOption.name, BudgetSortOption.nameDesc, context, align: TextAlign.center),  // #19: 중앙 정렬
                  _buildSortableHeaderCell(loc.tr('budget'), BudgetSortOption.amount, BudgetSortOption.amountDesc, context, align: TextAlign.center),
                  _buildSortableHeaderCell(loc.tr('used'), BudgetSortOption.used, BudgetSortOption.usedDesc, context, align: TextAlign.center),
                  _buildSortableHeaderCell(loc.tr('remaining'), BudgetSortOption.remaining, BudgetSortOption.remainingDesc, context, align: TextAlign.center),
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
        horizontal: SheetStyle.cellPaddingH,
        vertical: SheetStyle.cellPaddingV,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? SheetStyle.headerFontSize : SheetStyle.fontSize,
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

  // #2: 정렬 가능한 헤더 셀
  Widget _buildSortableHeaderCell(String text, BudgetSortOption ascOption, BudgetSortOption descOption, BuildContext context, {TextAlign align = TextAlign.left}) {
    final isAsc = _sortOption == ascOption;
    final isDesc = _sortOption == descOption;
    final isActive = isAsc || isDesc;

    return InkWell(
      onTap: () {
        setState(() {
          if (isAsc) {
            _sortOption = descOption;  // 오름차순 → 내림차순
          } else if (isDesc) {
            _sortOption = BudgetSortOption.order;  // #3: 내림차순 → 기본(순서)
          } else {
            _sortOption = ascOption;  // 비활성 → 오름차순
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: SheetStyle.cellPaddingH,
          vertical: SheetStyle.cellPaddingV,
        ),
        child: Row(
          mainAxisAlignment: align == TextAlign.center ? MainAxisAlignment.center : MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: SheetStyle.headerFontSize,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              isActive
                ? (isAsc ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
              size: isActive ? 12 : 10,
              color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  // #10: 월 선택 다이얼로그
  void _showMonthPickerDialog(BuildContext context, BudgetProvider provider) {
    final loc = context.loc;
    int selectedYear = provider.currentYear;
    int selectedMonth = provider.currentMonth;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(loc.tr('selectMonth')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 연도 선택
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() => selectedYear--),
                  ),
                  Text('$selectedYear년', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() => selectedYear++),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 월 선택 그리드
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final isSelected = month == selectedMonth;
                  return InkWell(
                    onTap: () => setState(() => selectedMonth = month),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$month월',
                        style: TextStyle(
                          color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(loc.tr('cancel'))),
            FilledButton(
              onPressed: () {
                provider.setYearMonth(selectedYear, selectedMonth);
                Navigator.pop(dialogContext);
              },
              child: Text(loc.tr('confirm')),
            ),
          ],
        ),
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
          // #36: 키보드가 올라올 때 다이얼로그가 화면 밖으로 나가지 않도록 insetPadding 조정
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          content: SingleChildScrollView(  // #1: 키보드 겹침 방지
            child: Column(mainAxisSize: MainAxisSize.min, children: [
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
          ),
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
    final border = BorderSide(color: SheetStyle.borderColor(context), width: SheetStyle.borderWidth);

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BudgetDetailScreen(budget: budget))),
      onLongPress: () => _showEditDeleteMenu(context),
      child: Table(
        border: TableBorder(
          verticalInside: border,
          bottom: border,
        ),
        columnWidths: const {
          0: FlexColumnWidth(3),    // 예산명 너비 확장 (#6)
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(2),
          3: FlexColumnWidth(2),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: isEven ? SheetStyle.evenRowBg(context) : SheetStyle.oddRowBg(context),
            ),
            children: [
              // 예산명 (반복 아이콘 제거 #7)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: SheetStyle.cellPaddingH,
                  vertical: SheetStyle.cellPaddingV,
                ),
                child: Text(
                  budget.name,
                  style: TextStyle(fontSize: SheetStyle.fontSize),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 예산액
              _buildDataCell(context.formatCurrency(budget.amount), context),
              // 사용액
              _buildDataCell(context.formatCurrency(expense), context),
              // 잔액
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: SheetStyle.cellPaddingH,
                  vertical: SheetStyle.cellPaddingV,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.formatCurrency(remaining),
                        style: TextStyle(
                          fontSize: SheetStyle.fontSize,
                          color: remaining < 0 ? Theme.of(context).colorScheme.error : null,
                          fontWeight: remaining < 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.more_vert, size: 16, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                  ],
                ),
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
        horizontal: SheetStyle.cellPaddingH,
        vertical: SheetStyle.cellPaddingV,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: SheetStyle.fontSize,
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
    final provider = context.read<BudgetProvider>();
    final budgets = provider.currentBudgets;
    final index = budgets.indexWhere((b) => b.id == budget.id);
    final isFirst = index == 0;
    final isLast = index == budgets.length - 1;

    showModalBottomSheet(context: context, builder: (sheetContext) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // #3: 위로 이동
        ListTile(
          leading: Icon(Icons.arrow_upward, color: isFirst ? Theme.of(sheetContext).disabledColor : null),
          title: Text(loc.tr('moveUp'), style: TextStyle(color: isFirst ? Theme.of(sheetContext).disabledColor : null)),
          onTap: isFirst ? null : () { Navigator.pop(sheetContext); provider.moveBudgetUp(budget.id); },
        ),
        // #3: 아래로 이동
        ListTile(
          leading: Icon(Icons.arrow_downward, color: isLast ? Theme.of(sheetContext).disabledColor : null),
          title: Text(loc.tr('moveDown'), style: TextStyle(color: isLast ? Theme.of(sheetContext).disabledColor : null)),
          onTap: isLast ? null : () { Navigator.pop(sheetContext); provider.moveBudgetDown(budget.id); },
        ),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.edit), title: Text(loc.tr('edit')), onTap: () { Navigator.pop(sheetContext); _showEditDialog(context); }),
        ListTile(leading: Icon(Icons.delete, color: Theme.of(sheetContext).colorScheme.error), title: Text(loc.tr('delete'), style: TextStyle(color: Theme.of(sheetContext).colorScheme.error)), onTap: () { Navigator.pop(sheetContext); _confirmDelete(context); }),
      ]),
    ));
  }

  void _showEditDialog(BuildContext context) {
    final loc = context.loc;
    final nameController = TextEditingController(text: budget.name);
    final settings = context.read<SettingsProvider>();
    final amountController = TextEditingController(text: NumberFormat('#,###', AppLocalizations.localeFor(settings.language)).format(budget.amount));
    bool isRecurring = budget.isRecurring;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(loc.tr('editBudget')),
          // #36: 키보드가 올라올 때 다이얼로그가 화면 밖으로 나가지 않도록 insetPadding 조정
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          content: SingleChildScrollView(  // #1: 키보드 겹침 방지
            child: Column(mainAxisSize: MainAxisSize.min, children: [
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
          ),
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
