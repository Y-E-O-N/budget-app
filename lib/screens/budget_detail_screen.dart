import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../app_localizations.dart';
import '../providers/budget_provider.dart';
import '../providers/settings_provider.dart';
import '../models/budget.dart';
import '../models/sub_budget.dart';
import '../models/expense.dart';
import '../services/receipt_ocr_service.dart';

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

// #25: 지출 내역 정렬 옵션
enum ExpenseSortOption { dateAsc, dateDesc }

class BudgetDetailScreen extends StatefulWidget {
  final Budget budget;
  const BudgetDetailScreen({super.key, required this.budget});

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  // #25: 기본 날짜 오름차순 정렬
  ExpenseSortOption _expenseSortOption = ExpenseSortOption.dateAsc;

  // #25: 정렬된 지출 목록 반환
  List<Expense> _getSortedExpenses(List<Expense> expenses) {
    final sorted = List<Expense>.from(expenses);
    switch (_expenseSortOption) {
      case ExpenseSortOption.dateAsc:
        sorted.sort((a, b) => a.date.compareTo(b.date));
        break;
      case ExpenseSortOption.dateDesc:
        sorted.sort((a, b) => b.date.compareTo(a.date));
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Consumer2<BudgetProvider, SettingsProvider>(
      builder: (context, provider, settings, child) {
        final subBudgets = provider.getSubBudgets(widget.budget.id);
        final rawExpenses = provider.getExpenses(widget.budget.id);
        final expenses = _getSortedExpenses(rawExpenses);  // #25: 정렬 적용
        final totalExpense = provider.getTotalExpense(widget.budget.id);
        final remaining = widget.budget.amount - totalExpense;
        final currencyFormat = NumberFormat('#,###', 'ko_KR');

        return Scaffold(
          // #15: 예산 상세에서 월 변경 가능
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.budget.name, style: const TextStyle(fontSize: 16)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () { provider.previousMonth(); Navigator.pop(context); },
                      child: const Icon(Icons.chevron_left, size: 18),
                    ),
                    Text('${provider.currentYear}년 ${provider.currentMonth}월', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                    InkWell(
                      onTap: () { provider.nextMonth(); Navigator.pop(context); },
                      child: const Icon(Icons.chevron_right, size: 18),
                    ),
                  ],
                ),
              ],
            ),
            actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddMenu(context, subBudgets))],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      _buildStatItem(loc.tr('budget'), context.formatCurrency(widget.budget.amount), context),
                      _buildStatItem(loc.tr('used'), context.formatCurrency(totalExpense), context, color: Theme.of(context).colorScheme.error),
                      _buildStatItem(loc.tr('remaining'), context.formatCurrency(remaining), context, color: remaining >= 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error),
                    ]),
                    const SizedBox(height: 12),
                    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                      value: widget.budget.amount > 0 ? (totalExpense / widget.budget.amount).clamp(0.0, 1.0) : 0,
                      minHeight: 8,
                      backgroundColor: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(totalExpense > widget.budget.amount ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary),
                    )),
                  ]),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(loc.tr('subBudget'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton.icon(onPressed: () => _showAddSubBudgetDialog(context), icon: const Icon(Icons.add, size: 16), label: Text(loc.tr('add'))),
                ])),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(4)),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)))),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text(loc.tr('item'), style: _headerStyle(context))),
                        Expanded(flex: 2, child: Text(loc.tr('budget'), style: _headerStyle(context), textAlign: TextAlign.right)),
                        Expanded(flex: 2, child: Text(loc.tr('used'), style: _headerStyle(context), textAlign: TextAlign.right)),
                        Expanded(flex: 2, child: Text(loc.tr('remaining'), style: _headerStyle(context), textAlign: TextAlign.right)),
                      ]),
                    ),
                    if (subBudgets.isEmpty)
                      Padding(padding: const EdgeInsets.all(16), child: Center(child: Text(loc.tr('addSubBudgetPlease'), style: TextStyle(color: Theme.of(context).colorScheme.outline))))
                    else
                      ...subBudgets.asMap().entries.map((entry) {
                        final sub = entry.value;
                        final subExpense = provider.getSubBudgetExpense(sub.id);
                        final subRemaining = sub.amount - subExpense;
                        return _SubBudgetRow(subBudget: sub, expense: subExpense, remaining: subRemaining, currencyFormat: currencyFormat, isLast: entry.key == subBudgets.length - 1, provider: provider);
                      }),
                  ]),
                ),
                const SizedBox(height: 16),
                Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(loc.tr('expenseHistory'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton.icon(onPressed: () => _showAddExpenseDialog(context, subBudgets), icon: const Icon(Icons.add, size: 16), label: Text(loc.tr('add'))),
                ])),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(4)),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)))),
                      child: Row(children: [
                        // #25: 날짜 헤더 터치로 정렬 순서 변경
                        SizedBox(width: 40, child: InkWell(
                          onTap: () => setState(() {
                            _expenseSortOption = _expenseSortOption == ExpenseSortOption.dateAsc
                                ? ExpenseSortOption.dateDesc
                                : ExpenseSortOption.dateAsc;
                          }),
                          child: Row(children: [
                            Text(loc.tr('date'), style: _headerStyle(context).copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            )),
                            const SizedBox(width: 2),
                            Icon(
                              _expenseSortOption == ExpenseSortOption.dateAsc ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ]),
                        )),
                        const SizedBox(width: 6),
                        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 76), child: Text(loc.tr('subBudget'), style: _headerStyle(context), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(loc.tr('memo'), style: _headerStyle(context))),
                        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 88), child: Text(loc.tr('amount'), style: _headerStyle(context), textAlign: TextAlign.right)),
                      ]),
                    ),
                    if (expenses.isEmpty)
                      Padding(padding: const EdgeInsets.all(16), child: Center(child: Text(loc.tr('noExpense'), style: TextStyle(color: Theme.of(context).colorScheme.outline))))
                    else
                      ...expenses.asMap().entries.map((entry) {
                        final exp = entry.value;
                        final subName = exp.subBudgetId != null ? subBudgets.where((s) => s.id == exp.subBudgetId).map((s) => s.name).firstOrNull : null;
                        return _ExpenseRow(expense: exp, subBudgetName: subName, currencyFormat: currencyFormat, isLast: entry.key == expenses.length - 1);
                      }),
                  ]),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, BuildContext context, {Color? color}) {
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7))),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color ?? Theme.of(context).colorScheme.onPrimaryContainer)),
    ]);
  }

  TextStyle _headerStyle(BuildContext context) => TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant);

  void _showAddMenu(BuildContext context, List<SubBudget> subBudgets) {
    final loc = context.loc;
    showModalBottomSheet(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.category), title: Text(loc.tr('addSubBudget')), onTap: () { Navigator.pop(context); _showAddSubBudgetDialog(context); }),
      ListTile(leading: const Icon(Icons.receipt), title: Text(loc.tr('addExpense')), onTap: () { Navigator.pop(context); _showAddExpenseDialog(context, subBudgets); }),
    ])));
  }

  void _showAddSubBudgetDialog(BuildContext context) {
    final loc = context.loc;
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    bool isRecurring = false;
    String? errorMessage;
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: Text(loc.tr('addSubBudget')),
      // #36: 키보드가 올라올 때 다이얼로그가 화면 밖으로 나가지 않도록 insetPadding 조정
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      content: SingleChildScrollView(  // #1: 키보드 겹침 방지
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, decoration: InputDecoration(labelText: loc.tr('subBudgetName'), hintText: loc.tr('subBudgetNameHint'), border: const OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: amountController, decoration: InputDecoration(labelText: loc.tr('amount'), hintText: '0', suffixText: context.currency, border: const OutlineInputBorder(), errorText: errorMessage), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()], onChanged: (value) { if (errorMessage != null) setState(() => errorMessage = null); }),
          const SizedBox(height: 16),
          CheckboxListTile(title: Text(loc.tr('applyMonthly')), value: isRecurring, onChanged: (value) => setState(() => isRecurring = value ?? false), contentPadding: EdgeInsets.zero),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.tr('cancel'))),
        FilledButton(onPressed: () {
          final name = nameController.text.trim();
          final amount = int.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
          if (name.isEmpty) return;
          if (amount <= 0) { setState(() => errorMessage = loc.tr('numberOnlyError')); return; }
          context.read<BudgetProvider>().addSubBudget(widget.budget.id, name, amount, isRecurring);
          Navigator.pop(context);
        }, child: Text(loc.tr('add'))),
      ],
    )));
  }

  // #38: 날짜 선택 시 회색 화면 버그 수정
  void _showAddExpenseDialog(BuildContext context, List<SubBudget> subBudgets) {
    final loc = context.loc;
    final settings = context.read<SettingsProvider>();
    final provider = context.read<BudgetProvider>();
    final rootContext = context;  // #38: DatePicker용 외부 context 저장
    final amountController = TextEditingController();
    final memoController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String? selectedSubBudgetId = subBudgets.any((s) => s.id == provider.lastSelectedSubBudgetId) ? provider.lastSelectedSubBudgetId : null;
    String? errorMessage;
    bool isProcessingOcr = false;

    showDialog(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setState) => AlertDialog(
      title: Text(loc.tr('addExpense')),
      // #36: 키보드가 올라올 때 다이얼로그가 화면 밖으로 나가지 않도록 insetPadding 조정
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 날짜 선택 + OCR 스캔 버튼
        Row(children: [
          Expanded(child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text(DateFormat('yyyy. M. d').format(selectedDate)),
            onTap: () async {
              // #38: dialogContext 대신 rootContext 사용하여 회색 화면 버그 수정
              final date = await showDatePicker(context: rootContext, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (date != null) setState(() => selectedDate = date);
            },
          )),
          // 영수증 스캔 버튼
          IconButton(
            icon: isProcessingOcr
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.document_scanner),
            tooltip: loc.tr('scanReceipt'),
            onPressed: isProcessingOcr ? null : () => _showImageSourcePicker(
              dialogContext, settings.language, setState,
              amountController, (date) => setState(() => selectedDate = date),
              (loading) => setState(() => isProcessingOcr = loading),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        if (subBudgets.isNotEmpty) ...[
          DropdownButtonFormField<String?>(value: selectedSubBudgetId, decoration: InputDecoration(labelText: loc.tr('subBudgetOptional'), border: const OutlineInputBorder()), items: [DropdownMenuItem(value: null, child: Text(loc.tr('notSelected'))), ...subBudgets.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))], onChanged: (value) => setState(() => selectedSubBudgetId = value)),
          const SizedBox(height: 16),
        ],
        TextField(controller: memoController, decoration: InputDecoration(labelText: loc.tr('memo'), hintText: loc.tr('memoHint'), border: const OutlineInputBorder())),
        const SizedBox(height: 16),
        TextField(controller: amountController, decoration: InputDecoration(labelText: loc.tr('usedAmount'), hintText: '0', suffixText: context.currency, border: const OutlineInputBorder(), errorText: errorMessage), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()], onChanged: (value) { if (errorMessage != null) setState(() => errorMessage = null); }),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(loc.tr('cancel'))),
        FilledButton(onPressed: () {
          final amount = int.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
          if (amount <= 0) { setState(() => errorMessage = loc.tr('numberOnlyError')); return; }
          provider.setLastSelectedSubBudgetId(selectedSubBudgetId);
          provider.addExpense(widget.budget.id, selectedSubBudgetId, amount, selectedDate, memo: memoController.text.trim().isEmpty ? null : memoController.text.trim());
          Navigator.pop(dialogContext);
        }, child: Text(loc.tr('add'))),
      ],
    )));
  }

  // 이미지 소스 선택 (카메라/갤러리)
  void _showImageSourcePicker(
    BuildContext context,
    String language,
    StateSetter setState,
    TextEditingController amountController,
    Function(DateTime) onDateChanged,
    Function(bool) setLoading,
  ) {
    final loc = context.loc;
    showModalBottomSheet(
      context: context,
      builder: (bottomContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(loc.tr('selectImageSource'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: Text(loc.tr('camera')),
            onTap: () {
              Navigator.pop(bottomContext);
              _processReceiptOcr(context, language, ImageSource.camera, setState, amountController, onDateChanged, setLoading);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: Text(loc.tr('gallery')),
            onTap: () {
              Navigator.pop(bottomContext);
              _processReceiptOcr(context, language, ImageSource.gallery, setState, amountController, onDateChanged, setLoading);
            },
          ),
        ]),
      ),
    );
  }

  // 영수증 OCR 처리
  Future<void> _processReceiptOcr(
    BuildContext context,
    String language,
    ImageSource source,
    StateSetter setState,
    TextEditingController amountController,
    Function(DateTime) onDateChanged,
    Function(bool) setLoading,
  ) async {
    final loc = context.loc;
    final ocrService = ReceiptOcrService(language: language);
    final formatter = NumberFormat('#,###', 'ko_KR');

    try {
      setLoading(true);

      // 이미지 선택 (Result 기반)
      final imageResult = await ocrService.pickImageAsResult(source);
      final imageFile = imageResult.dataOrNull;
      if (imageFile == null) {
        setLoading(false);
        return;
      }

      // OCR 처리 (Result 기반)
      final ocrResult = await ocrService.process(imageFile);
      setLoading(false);

      // Result 패턴으로 처리
      ocrResult.fold(
        onSuccess: (data) {
          final messages = <String>[];

          if (data.amount != null) {
            amountController.text = formatter.format(data.amount);
            messages.add(loc.tr('amount'));
          } else {
            messages.add(loc.tr('ocrAmountNotFound'));
          }

          if (data.date != null) {
            onDateChanged(data.date!);
            messages.add(loc.tr('date'));
          }

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(data.amount != null ? loc.tr('ocrSuccess') : messages.join(', ')),
              duration: const Duration(seconds: 2),
            ));
          }
        },
        onFailure: (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ocrService.getErrorMessage(error)),
            ));
          }
        },
      );
    } catch (e) {
      setLoading(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.tr('ocrFailed'))));
      }
    } finally {
      ocrService.dispose();
    }
  }
}

class _SubBudgetRow extends StatelessWidget {
  final SubBudget subBudget;
  final int expense;
  final int remaining;
  final NumberFormat currencyFormat;
  final bool isLast;
  final BudgetProvider provider;

  const _SubBudgetRow({required this.subBudget, required this.expense, required this.remaining, required this.currencyFormat, required this.isLast, required this.provider});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showExpensesBySubBudget(context),
      onLongPress: () => _showEditDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)))),
        child: Row(children: [
          Expanded(flex: 3, child: Row(children: [
            Expanded(child: Text(subBudget.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
            if (subBudget.isRecurring) Icon(Icons.repeat, size: 12, color: Theme.of(context).colorScheme.primary),
          ])),
          Expanded(flex: 2, child: Text(context.formatCurrency(subBudget.amount), style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(context.formatCurrency(expense), style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(context.formatCurrency(remaining), style: TextStyle(fontSize: 13, color: remaining < 0 ? Theme.of(context).colorScheme.error : null, fontWeight: remaining < 0 ? FontWeight.w600 : null), textAlign: TextAlign.right)),
        ]),
      ),
    );
  }

  void _showExpensesBySubBudget(BuildContext context) {
    final loc = context.loc;
    final expenses = provider.getExpenses(subBudget.budgetId).where((e) => e.subBudgetId == subBudget.id).toList();
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
      builder: (context, scrollController) => Column(children: [
        Container(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${subBudget.name} ${loc.tr('expenseHistory')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ])),
        Expanded(child: expenses.isEmpty
          ? Center(child: Text(loc.tr('noExpense'), style: TextStyle(color: Theme.of(context).colorScheme.outline)))
          : ListView.builder(controller: scrollController, itemCount: expenses.length, itemBuilder: (context, index) {
              final exp = expenses[index];
              return ListTile(
                leading: Text(DateFormat('M/d').format(exp.date), style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                title: Text(exp.memo ?? '-'),
                trailing: Text('-${context.formatCurrency(exp.amount)}', style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w500)),
              );
            }),
        ),
      ]),
    ));
  }

  void _showEditDialog(BuildContext context) {
    final loc = context.loc;
    final nameController = TextEditingController(text: subBudget.name);
    final amountController = TextEditingController(text: currencyFormat.format(subBudget.amount));
    bool isRecurring = subBudget.isRecurring;
    String? errorMessage;
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: Text(loc.tr('editSubBudget')),
      // #36: 키보드가 올라올 때 다이얼로그가 화면 밖으로 나가지 않도록 insetPadding 조정
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      content: SingleChildScrollView(  // #1: 키보드 겹침 방지
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, decoration: InputDecoration(labelText: loc.tr('subBudgetName'), border: const OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: amountController, decoration: InputDecoration(labelText: loc.tr('amount'), suffixText: context.currency, border: const OutlineInputBorder(), errorText: errorMessage), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()], onChanged: (value) { if (errorMessage != null) setState(() => errorMessage = null); }),
          const SizedBox(height: 16),
          CheckboxListTile(title: Text(loc.tr('applyMonthly')), value: isRecurring, onChanged: (value) => setState(() => isRecurring = value ?? false), contentPadding: EdgeInsets.zero),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.tr('cancel'))),
        TextButton(onPressed: () async {
          Navigator.pop(context);
          final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(loc.tr('deleteConfirm')), content: Text("'${subBudget.name}'"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.tr('cancel'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error), child: Text(loc.tr('delete')))]));
          if (confirm == true && context.mounted) context.read<BudgetProvider>().deleteSubBudget(subBudget.id);
        }, child: Text(loc.tr('delete'), style: TextStyle(color: Theme.of(context).colorScheme.error))),
        FilledButton(onPressed: () {
          final name = nameController.text.trim();
          final amount = int.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
          if (name.isEmpty) return;
          if (amount <= 0) { setState(() => errorMessage = loc.tr('numberOnlyError')); return; }
          context.read<BudgetProvider>().updateSubBudget(subBudget.copyWith(name: name, amount: amount, isRecurring: isRecurring));
          Navigator.pop(context);
        }, child: Text(loc.tr('save'))),
      ],
    )));
  }
}

class _ExpenseRow extends StatelessWidget {
  final Expense expense;
  final String? subBudgetName;
  final NumberFormat currencyFormat;
  final bool isLast;

  const _ExpenseRow({required this.expense, this.subBudgetName, required this.currencyFormat, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: () => _showOptionsMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)))),
        child: Row(children: [
          SizedBox(width: 40, child: Text(DateFormat('M/d').format(expense.date), style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline))),
          const SizedBox(width: 6),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 76), child: Text(subBudgetName ?? '-', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          Expanded(child: Text(expense.memo ?? '-', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 88), child: Text('-${context.formatCurrency(expense.amount)}', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
        ]),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    final loc = context.loc;
    showModalBottomSheet(context: context, builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        child: Text('${expense.memo ?? loc.tr('expense')} - ${sheetContext.formatCurrency(expense.amount)}', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      ),
      const Divider(height: 1),
      // #35: 수정 기능 추가
      ListTile(leading: const Icon(Icons.edit), title: Text(loc.tr('edit')), onTap: () {
        Navigator.pop(sheetContext);
        _editExpense(context);
      }),
      ListTile(leading: const Icon(Icons.copy), title: Text(loc.tr('duplicate')), onTap: () {
        Navigator.pop(sheetContext);
        _duplicateExpense(context);
      }),
      ListTile(leading: Icon(Icons.delete, color: Theme.of(sheetContext).colorScheme.error), title: Text(loc.tr('delete'), style: TextStyle(color: Theme.of(sheetContext).colorScheme.error)), onTap: () {
        Navigator.pop(sheetContext);
        _showDeleteDialog(context);
      }),
    ])));
  }

  // #14: 복제 기능 수정 - 날짜 선택 후 등록
  // #38: 금액 오류 시 에러 메시지 표시, 날짜 선택 시 회색 화면 버그 수정
  void _duplicateExpense(BuildContext context) {
    final loc = context.loc;
    final provider = context.read<BudgetProvider>();
    final rootContext = context;  // #38: DatePicker용 외부 context 저장
    DateTime selectedDate = DateTime.now();  // 기본값: 오늘
    final amountController = TextEditingController(text: NumberFormat('#,###').format(expense.amount));
    final memoController = TextEditingController(text: expense.memo ?? '');
    String? errorMessage;  // #38: 에러 메시지 추가

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(loc.tr('duplicateExpense')),
          // #36: 키보드가 올라올 때 다이얼로그가 화면 밖으로 나가지 않도록 insetPadding 조정
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜 선택
                Row(children: [
                  Text(loc.tr('date'), style: const TextStyle(fontWeight: FontWeight.w500)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                    onPressed: () async {
                      // #38: dialogContext 대신 rootContext 사용하여 회색 화면 버그 수정
                      final picked = await showDatePicker(
                        context: rootContext,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                  ),
                ]),
                const SizedBox(height: 16),
                // 메모
                TextField(
                  controller: memoController,
                  decoration: InputDecoration(labelText: loc.tr('memo'), border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                // 금액 (#38: 에러 메시지 표시)
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: loc.tr('amount'),
                    suffixText: context.currency,
                    border: const OutlineInputBorder(),
                    errorText: errorMessage,
                  ),
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
                // #38: 금액 오류 시 에러 메시지 표시
                if (amount <= 0) {
                  setState(() => errorMessage = loc.tr('numberOnlyError'));
                  return;
                }
                provider.addExpense(
                  expense.budgetId,
                  expense.subBudgetId,
                  amount,
                  selectedDate,
                  memo: memoController.text.trim().isEmpty ? null : memoController.text.trim(),
                );
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.tr('duplicated')), duration: const Duration(seconds: 2)));
              },
              child: Text(loc.tr('add')),
            ),
          ],
        ),
      ),
    );
  }

  // #35: 지출 내역 수정 기능
  // #38: 날짜 선택 시 회색 화면 버그 수정
  void _editExpense(BuildContext context) {
    final loc = context.loc;
    final provider = context.read<BudgetProvider>();
    final rootContext = context;  // #38: DatePicker용 외부 context 저장
    final subBudgets = provider.getSubBudgets(expense.budgetId);
    DateTime selectedDate = expense.date;
    final amountController = TextEditingController(text: NumberFormat('#,###').format(expense.amount));
    final memoController = TextEditingController(text: expense.memo ?? '');
    String? selectedSubBudgetId = expense.subBudgetId;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(loc.tr('editExpense')),
          // #36: 키보드가 올라올 때 다이얼로그가 화면 밖으로 나가지 않도록 insetPadding 조정
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜 선택
                Row(children: [
                  Text(loc.tr('date'), style: const TextStyle(fontWeight: FontWeight.w500)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                    onPressed: () async {
                      // #38: dialogContext 대신 rootContext 사용하여 회색 화면 버그 수정
                      final picked = await showDatePicker(
                        context: rootContext,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                  ),
                ]),
                const SizedBox(height: 12),
                // 세부예산 선택
                if (subBudgets.isNotEmpty) ...[
                  DropdownButtonFormField<String?>(
                    value: selectedSubBudgetId,
                    decoration: InputDecoration(labelText: loc.tr('subBudgetOptional'), border: const OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(value: null, child: Text(loc.tr('notSelected'))),
                      ...subBudgets.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (value) => setState(() => selectedSubBudgetId = value),
                  ),
                  const SizedBox(height: 16),
                ],
                // 메모
                TextField(
                  controller: memoController,
                  decoration: InputDecoration(labelText: loc.tr('memo'), border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                // 금액
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: loc.tr('amount'),
                    suffixText: context.currency,
                    border: const OutlineInputBorder(),
                    errorText: errorMessage,
                  ),
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
                if (amount <= 0) {
                  setState(() => errorMessage = loc.tr('numberOnlyError'));
                  return;
                }
                // 수정된 지출 저장 (새 Expense 객체 생성 - subBudgetId를 null로 변경 가능하도록)
                final updatedExpense = Expense(
                  id: expense.id,
                  budgetId: expense.budgetId,
                  subBudgetId: selectedSubBudgetId,  // null 허용
                  amount: amount,
                  date: selectedDate,
                  memo: memoController.text.trim().isEmpty ? null : memoController.text.trim(),
                );
                provider.updateExpense(updatedExpense);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.tr('saved')), duration: const Duration(seconds: 2)));
              },
              child: Text(loc.tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final loc = context.loc;
    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text(loc.tr('deleteConfirm')),
      content: Text(expense.memo ?? ''),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.tr('cancel'))),
        FilledButton(onPressed: () { context.read<BudgetProvider>().deleteExpense(expense.id); Navigator.pop(context); }, style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), child: Text(loc.tr('delete'))),
      ],
    ));
  }
}
