// =============================================================================
// history_tab.dart - 지출 내역 탭 (스프레드시트 스타일)
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_localizations.dart';
import '../providers/budget_provider.dart';
import '../providers/settings_provider.dart';
import '../models/expense.dart';

// 천 단위 포맷터
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
  static const double borderWidth = 1.0;
  static const double cellPaddingH = 8.0;
  static const double cellPaddingV = 10.0;
  static const double fontSize = 13.0;
  static const double headerFontSize = 12.0;

  static Color borderColor(BuildContext context) =>
    Theme.of(context).dividerColor.withValues(alpha: 0.5);

  static Color headerBg(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHighest;

  static Color evenRowBg(BuildContext context) =>
    Theme.of(context).colorScheme.surface;

  static Color oddRowBg(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerLowest;
}

// 정렬 옵션
enum SortOption { dateDesc, dateAsc, amountDesc, amountAsc }

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});
  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedBudgetId;
  String? _selectedSubBudgetId;
  SortOption _sortOption = SortOption.dateDesc;
  bool _isFilterExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _startDate = null;
      _endDate = null;
      _selectedBudgetId = null;
      _selectedSubBudgetId = null;
      _sortOption = SortOption.dateDesc;
    });
  }

  List<Expense> _getFilteredExpenses(BudgetProvider provider) {
    List<Expense> expenses = provider.allExpenses;

    if (_startDate != null) {
      expenses = expenses.where((e) =>
        e.date.isAfter(_startDate!.subtract(const Duration(days: 1)))).toList();
    }
    if (_endDate != null) {
      expenses = expenses.where((e) =>
        e.date.isBefore(_endDate!.add(const Duration(days: 1)))).toList();
    }
    if (_selectedBudgetId != null) {
      expenses = expenses.where((e) => e.budgetId == _selectedBudgetId).toList();
    }
    if (_selectedSubBudgetId != null) {
      expenses = expenses.where((e) => e.subBudgetId == _selectedSubBudgetId).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      expenses = expenses.where((e) {
        final memo = e.memo?.toLowerCase() ?? '';
        final budget = provider.getBudgetById(e.budgetId);
        final budgetName = budget?.name.toLowerCase() ?? '';
        final subBudget = e.subBudgetId != null ? provider.getSubBudgetById(e.subBudgetId!) : null;
        final subBudgetName = subBudget?.name.toLowerCase() ?? '';
        return memo.contains(query) || budgetName.contains(query) || subBudgetName.contains(query);
      }).toList();
    }

    switch (_sortOption) {
      case SortOption.dateDesc:
        expenses.sort((a, b) => b.date.compareTo(a.date));
        break;
      case SortOption.dateAsc:
        expenses.sort((a, b) => a.date.compareTo(b.date));
        break;
      case SortOption.amountDesc:
        expenses.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case SortOption.amountAsc:
        expenses.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }

    return expenses;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Consumer2<BudgetProvider, SettingsProvider>(
      builder: (context, provider, settings, child) {
        final filteredExpenses = _getFilteredExpenses(provider);
        final totalAmount = filteredExpenses.fold(0, (sum, e) => sum + e.amount);

        final budgetMap = <String, String>{};
        for (final b in provider.allBudgets) {
          budgetMap[b.id] = b.name;
        }
        final uniqueBudgets = budgetMap.entries.toList();

        final subBudgets = _selectedBudgetId != null
            ? provider.allSubBudgets.where((s) => s.budgetId == _selectedBudgetId).toList()
            : <dynamic>[];

        return Scaffold(
          appBar: AppBar(
            title: Text(loc.tr('historyTab')),
            actions: [
              IconButton(
                icon: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list),
                tooltip: loc.tr('filter'),
                onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
              ),
            ],
          ),
          body: Column(
            children: [
              // 검색바
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: loc.tr('searchHint'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          })
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),

              // 필터 패널
              if (_isFilterExpanded) _buildFilterPanel(context, loc, uniqueBudgets, subBudgets),

              // 요약 행 + 정렬
              Container(
                margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  border: Border.all(color: _SheetStyle.borderColor(context)),
                ),
                child: Row(
                  children: [
                    Text(
                      '${filteredExpenses.length}${loc.tr('countUnit')}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.formatCurrency(totalAmount),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                    ),
                    const Spacer(),
                    // 정렬 버튼
                    InkWell(
                      onTap: () => _showSortMenu(context, loc),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: _SheetStyle.borderColor(context)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort, size: 14),
                            const SizedBox(width: 4),
                            Text(_getSortLabel(loc), style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 테이블 헤더
              _buildTableHeader(context, loc),

              // 테이블 바디 (지출 목록)
              Expanded(
                child: filteredExpenses.isEmpty
                    ? _buildEmptyState(context, loc)
                    : _buildDataTable(context, filteredExpenses, provider, loc),
              ),
            ],
          ),
        );
      },
    );
  }

  // 테이블 헤더
  Widget _buildTableHeader(BuildContext context, AppLocalizations loc) {
    final border = BorderSide(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(left: border, right: border, bottom: border),
        color: _SheetStyle.headerBg(context),
      ),
      child: Table(
        border: TableBorder(verticalInside: border),
        columnWidths: const {
          0: FixedColumnWidth(70),   // 날짜
          1: FlexColumnWidth(1.5),   // 카테고리
          2: FlexColumnWidth(2),     // 메모
          3: FlexColumnWidth(1.5),   // 금액
        },
        children: [
          TableRow(
            children: [
              _buildHeaderCell(loc.tr('date'), context),
              _buildHeaderCell(loc.tr('budget'), context),
              _buildHeaderCell(loc.tr('memo'), context),
              _buildHeaderCell(loc.tr('amount'), context, align: TextAlign.right),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, BuildContext context, {TextAlign align = TextAlign.left}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _SheetStyle.cellPaddingH, vertical: _SheetStyle.cellPaddingV),
      child: Text(
        text,
        style: TextStyle(
          fontSize: _SheetStyle.headerFontSize,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        textAlign: align,
      ),
    );
  }

  // 데이터 테이블
  Widget _buildDataTable(BuildContext context, List<Expense> expenses, BudgetProvider provider, AppLocalizations loc) {
    final border = BorderSide(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth);

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        border: Border(left: border, right: border, bottom: border),
      ),
      child: ListView.builder(
        itemCount: expenses.length,
        itemBuilder: (context, index) {
          final expense = expenses[index];
          return _ExpenseRow(
            expense: expense,
            provider: provider,
            loc: loc,
            isEven: index % 2 == 0,
            isLast: index == expenses.length - 1,
            onLongPress: () => _showExpenseOptions(context, expense, provider, loc),
          );
        },
      ),
    );
  }

  // 필터 패널
  Widget _buildFilterPanel(BuildContext context, AppLocalizations loc, List<MapEntry<String, String>> budgets, List<dynamic> subBudgets) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _SheetStyle.headerBg(context),
        border: Border.all(color: _SheetStyle.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 기간 선택
          Text(loc.tr('periodFilter'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                  onPressed: () async {
                    final picked = await showDatePicker(context: context, initialDate: _startDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (picked != null) setState(() => _startDate = picked);
                  },
                  child: Text(_startDate != null ? dateFormat.format(_startDate!) : loc.tr('startDate'), style: const TextStyle(fontSize: 12)),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('~', style: TextStyle(fontSize: 12))),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                  onPressed: () async {
                    final picked = await showDatePicker(context: context, initialDate: _endDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (picked != null) setState(() => _endDate = picked);
                  },
                  child: Text(_endDate != null ? dateFormat.format(_endDate!) : loc.tr('endDate'), style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 예산 선택
          Text(loc.tr('budgetFilter'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(border: Border.all(color: _SheetStyle.borderColor(context))),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                isDense: true,
                value: _selectedBudgetId,
                hint: Text(loc.tr('allBudgets'), style: const TextStyle(fontSize: 13)),
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text(loc.tr('allBudgets'))),
                  ...budgets.map((b) => DropdownMenuItem<String?>(value: b.key, child: Text(b.value))),
                ],
                onChanged: (value) => setState(() { _selectedBudgetId = value; _selectedSubBudgetId = null; }),
              ),
            ),
          ),

          if (_selectedBudgetId != null && subBudgets.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(loc.tr('subBudgetFilter'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(border: Border.all(color: _SheetStyle.borderColor(context))),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  isDense: true,
                  value: _selectedSubBudgetId,
                  hint: Text(loc.tr('allSubBudgets'), style: const TextStyle(fontSize: 13)),
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(loc.tr('allSubBudgets'))),
                    ...subBudgets.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name))),
                  ],
                  onChanged: (value) => setState(() => _selectedSubBudgetId = value),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(loc.tr('resetFilter'), style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.table_rows_outlined, size: 64, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(loc.tr('noExpenseFound'), style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }

  void _showSortMenu(BuildContext context, AppLocalizations loc) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(_sortOption == SortOption.dateDesc ? Icons.check : null),
              title: Text(loc.tr('sortDateDesc')),
              onTap: () { setState(() => _sortOption = SortOption.dateDesc); Navigator.pop(ctx); },
            ),
            ListTile(
              leading: Icon(_sortOption == SortOption.dateAsc ? Icons.check : null),
              title: Text(loc.tr('sortDateAsc')),
              onTap: () { setState(() => _sortOption = SortOption.dateAsc); Navigator.pop(ctx); },
            ),
            ListTile(
              leading: Icon(_sortOption == SortOption.amountDesc ? Icons.check : null),
              title: Text(loc.tr('sortAmountDesc')),
              onTap: () { setState(() => _sortOption = SortOption.amountDesc); Navigator.pop(ctx); },
            ),
            ListTile(
              leading: Icon(_sortOption == SortOption.amountAsc ? Icons.check : null),
              title: Text(loc.tr('sortAmountAsc')),
              onTap: () { setState(() => _sortOption = SortOption.amountAsc); Navigator.pop(ctx); },
            ),
          ],
        ),
      ),
    );
  }

  void _showExpenseOptions(BuildContext context, Expense expense, BudgetProvider provider, AppLocalizations loc) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
              title: Text(loc.tr('edit')),
              onTap: () { Navigator.pop(sheetContext); _showEditExpenseDialog(context, expense, provider, loc); },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text(loc.tr('delete'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(loc.tr('deleteConfirm')),
                    content: Text(loc.tr('deleteExpenseConfirm')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.tr('cancel'))),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(loc.tr('delete'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) await provider.deleteExpense(expense.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditExpenseDialog(BuildContext context, Expense expense, BudgetProvider provider, AppLocalizations loc) {
    final amountController = TextEditingController(text: NumberFormat('#,###').format(expense.amount));
    final memoController = TextEditingController(text: expense.memo ?? '');
    DateTime selectedDate = expense.date;
    String? selectedSubBudgetId = expense.subBudgetId;
    String? errorMessage;

    final budget = provider.getBudgetById(expense.budgetId);
    if (budget == null) return;
    final subBudgets = provider.getSubBudgets(expense.budgetId);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(loc.tr('editExpense')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${loc.tr('budget')}: ${budget.name}', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13)),
                const SizedBox(height: 16),
                Row(children: [
                  Text(loc.tr('date'), style: const TextStyle(fontWeight: FontWeight.w500)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                    onPressed: () async {
                      final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                  ),
                ]),
                const SizedBox(height: 8),
                if (subBudgets.isNotEmpty) ...[
                  DropdownButtonFormField<String?>(
                    initialValue: selectedSubBudgetId,
                    decoration: InputDecoration(labelText: loc.tr('subBudgetOptional'), border: const OutlineInputBorder()),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text(loc.tr('notSelected'))),
                      ...subBudgets.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (value) => setState(() => selectedSubBudgetId = value),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(controller: memoController, decoration: InputDecoration(labelText: loc.tr('memo'), hintText: loc.tr('memoHint'), border: const OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(labelText: loc.tr('usedAmount'), suffixText: context.currency, border: const OutlineInputBorder(), errorText: errorMessage),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()],
                  onChanged: (value) { if (errorMessage != null) setState(() => errorMessage = null); },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(loc.tr('cancel'))),
            FilledButton(
              onPressed: () {
                final amount = int.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
                if (amount <= 0) { setState(() => errorMessage = loc.tr('numberOnlyError')); return; }
                final updatedExpense = Expense(id: expense.id, budgetId: expense.budgetId, subBudgetId: selectedSubBudgetId, amount: amount, date: selectedDate, memo: memoController.text.trim().isEmpty ? null : memoController.text.trim());
                provider.updateExpense(updatedExpense);
                Navigator.pop(dialogContext);
              },
              child: Text(loc.tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  String _getSortLabel(AppLocalizations loc) {
    switch (_sortOption) {
      case SortOption.dateDesc: return loc.tr('sortDateDesc');
      case SortOption.dateAsc: return loc.tr('sortDateAsc');
      case SortOption.amountDesc: return loc.tr('sortAmountDesc');
      case SortOption.amountAsc: return loc.tr('sortAmountAsc');
    }
  }
}

// =============================================================================
// 지출 행 위젯 (스프레드시트 스타일)
// =============================================================================
class _ExpenseRow extends StatelessWidget {
  final Expense expense;
  final BudgetProvider provider;
  final AppLocalizations loc;
  final bool isEven;
  final bool isLast;
  final VoidCallback onLongPress;

  const _ExpenseRow({
    required this.expense,
    required this.provider,
    required this.loc,
    required this.isEven,
    required this.isLast,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final budget = provider.getBudgetById(expense.budgetId);
    final subBudget = expense.subBudgetId != null ? provider.getSubBudgetById(expense.subBudgetId!) : null;
    final dateFormat = DateFormat('MM/dd');
    final border = BorderSide(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth);

    // 카테고리 표시: 예산명 또는 예산명 > 세부예산명
    String category = budget?.name ?? '-';
    if (subBudget != null) {
      category = '${budget?.name ?? ''} > ${subBudget.name}';
    }

    return InkWell(
      onLongPress: onLongPress,
      child: Table(
        border: TableBorder(
          verticalInside: border,
          bottom: isLast ? BorderSide.none : border,
        ),
        columnWidths: const {
          0: FixedColumnWidth(70),   // 날짜
          1: FlexColumnWidth(1.5),   // 카테고리
          2: FlexColumnWidth(2),     // 메모
          3: FlexColumnWidth(1.5),   // 금액
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: isEven ? _SheetStyle.evenRowBg(context) : _SheetStyle.oddRowBg(context),
            ),
            children: [
              // 날짜
              _buildCell(dateFormat.format(expense.date), context),
              // 카테고리
              _buildCell(category, context, maxLines: 1),
              // 메모
              _buildCell(expense.memo ?? '-', context, maxLines: 1),
              // 금액
              _buildCell(
                context.formatCurrency(expense.amount),
                context,
                align: TextAlign.right,
                textColor: Theme.of(context).colorScheme.primary,
                bold: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCell(String text, BuildContext context, {
    TextAlign align = TextAlign.left,
    Color? textColor,
    bool bold = false,
    int maxLines = 1,
  }) {
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
        textAlign: align,
        overflow: TextOverflow.ellipsis,
        maxLines: maxLines,
      ),
    );
  }
}
