// =============================================================================
// recurring_expense_screen.dart - 반복 지출 관리 화면
// =============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_localizations.dart';
import '../providers/budget_provider.dart';
import '../providers/recurring_expense_provider.dart';
import '../models/recurring_expense.dart';

class RecurringExpenseScreen extends StatelessWidget {
  const RecurringExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tr('recurringExpense')),
      ),
      // Consumer2: BudgetProvider(예산 데이터) + RecurringExpenseProvider(반복 지출)
      body: Consumer2<BudgetProvider, RecurringExpenseProvider>(
        builder: (context, budgetProvider, recurringProvider, child) {
          final recurringList = recurringProvider.recurringExpenses;

          if (recurringList.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat, size: 64, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(loc.tr('noRecurringExpense'), style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.outline)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddDialog(context, budgetProvider, recurringProvider, loc),
                    icon: const Icon(Icons.add),
                    label: Text(loc.tr('addRecurringExpense')),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recurringList.length,
            itemBuilder: (context, index) {
              final recurring = recurringList[index];
              return _buildRecurringItem(context, recurring, budgetProvider, recurringProvider, loc);
            },
          );
        },
      ),
      floatingActionButton: Consumer2<BudgetProvider, RecurringExpenseProvider>(
        builder: (context, budgetProvider, recurringProvider, child) {
          if (recurringProvider.recurringExpenses.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: () => _showAddDialog(context, budgetProvider, recurringProvider, loc),
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  // 반복 지출 아이템 - BudgetProvider(예산 정보) + RecurringExpenseProvider(반복 지출 작업)
  Widget _buildRecurringItem(BuildContext context, RecurringExpense recurring, BudgetProvider budgetProvider, RecurringExpenseProvider recurringProvider, AppLocalizations loc) {
    final budget = budgetProvider.getBudgetById(recurring.budgetId);
    final subBudget = recurring.subBudgetId != null ? budgetProvider.getSubBudgetById(recurring.subBudgetId!) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: recurring.isActive
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.repeat,
            color: recurring.isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                recurring.memo?.isNotEmpty == true ? recurring.memo! : budget?.name ?? '-',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: recurring.isActive ? null : Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            Text(
              context.formatCurrency(recurring.amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: recurring.isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  _getScheduleText(recurring, loc),
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ),
            if (budget != null) ...[
              const SizedBox(height: 2),
              Text(
                '${budget.name}${subBudget != null ? ' > ${subBudget.name}' : ''}',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ],
        ),
        trailing: Switch(
          value: recurring.isActive,
          // RecurringExpenseProvider의 toggle 메서드 사용
          onChanged: (_) => recurringProvider.toggle(recurring.id),
        ),
        onTap: () => _showEditDialog(context, recurring, budgetProvider, recurringProvider, loc),
        onLongPress: () => _showDeleteDialog(context, recurring, recurringProvider, loc),
      ),
    );
  }

  // 주기 텍스트
  String _getScheduleText(RecurringExpense recurring, AppLocalizations loc) {
    if (recurring.repeatType == RepeatType.weekly) {
      final weekdays = [
        loc.tr('monShort'), loc.tr('tueShort'), loc.tr('wedShort'),
        loc.tr('thuShort'), loc.tr('friShort'), loc.tr('satShort'), loc.tr('sunShort'),
      ];
      return '${loc.tr('everyWeek')} ${weekdays[recurring.dayOfWeek ?? 0]}';
    } else {
      return '${loc.tr('everyMonth')} ${loc.formatDayOfMonth(recurring.dayOfMonth)}';
    }
  }

  // 추가 다이얼로그 - BudgetProvider(예산 목록) + RecurringExpenseProvider(저장)
  void _showAddDialog(BuildContext context, BudgetProvider budgetProvider, RecurringExpenseProvider recurringProvider, AppLocalizations loc) {
    _showRecurringDialog(context, null, budgetProvider, recurringProvider, loc);
  }

  // 수정 다이얼로그 - BudgetProvider(예산 목록) + RecurringExpenseProvider(저장)
  void _showEditDialog(BuildContext context, RecurringExpense recurring, BudgetProvider budgetProvider, RecurringExpenseProvider recurringProvider, AppLocalizations loc) {
    _showRecurringDialog(context, recurring, budgetProvider, recurringProvider, loc);
  }

  // 추가/수정 다이얼로그 - BudgetProvider(예산 목록) + RecurringExpenseProvider(저장)
  void _showRecurringDialog(BuildContext context, RecurringExpense? existing, BudgetProvider budgetProvider, RecurringExpenseProvider recurringProvider, AppLocalizations loc) {
    final isEdit = existing != null;
    final budgets = budgetProvider.currentBudgets;

    if (budgets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.tr('addBudgetFirst'))),
      );
      return;
    }

    String? selectedBudgetId = existing?.budgetId ?? budgets.first.id;
    String? selectedSubBudgetId = existing?.subBudgetId;
    final amountController = TextEditingController(text: existing?.amount.toString() ?? '');
    final memoController = TextEditingController(text: existing?.memo ?? '');
    RepeatType repeatType = existing?.repeatType ?? RepeatType.monthly;
    int dayOfWeek = existing?.dayOfWeek ?? 0;
    int dayOfMonth = existing?.dayOfMonth ?? 1;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final subBudgets = budgetProvider.getSubBudgets(selectedBudgetId!);

          return AlertDialog(
            title: Text(isEdit ? loc.tr('editRecurringExpense') : loc.tr('addRecurringExpense')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 예산 선택
                  Text(loc.tr('budget'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(dialogContext).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedBudgetId,
                        items: budgets.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                        onChanged: (value) => setDialogState(() {
                          selectedBudgetId = value;
                          selectedSubBudgetId = null;
                        }),
                      ),
                    ),
                  ),

                  // 세부예산 선택
                  if (subBudgets.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(loc.tr('subBudgetOptional'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(dialogContext).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: selectedSubBudgetId,
                          hint: Text(loc.tr('notSelected')),
                          items: [
                            DropdownMenuItem<String?>(value: null, child: Text(loc.tr('notSelected'))),
                            ...subBudgets.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name))),
                          ],
                          onChanged: (value) => setDialogState(() => selectedSubBudgetId = value),
                        ),
                      ),
                    ),
                  ],

                  // 금액
                  const SizedBox(height: 12),
                  Text(loc.tr('amount'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),

                  // 메모
                  const SizedBox(height: 12),
                  Text(loc.tr('memo'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: memoController,
                    decoration: InputDecoration(
                      hintText: loc.tr('memoHint'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),

                  // 반복 주기
                  const SizedBox(height: 16),
                  Text(loc.tr('repeatCycle'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<RepeatType>(
                          title: Text(loc.tr('monthly'), style: const TextStyle(fontSize: 14)),
                          value: RepeatType.monthly,
                          groupValue: repeatType,
                          onChanged: (v) => setDialogState(() => repeatType = v!),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<RepeatType>(
                          title: Text(loc.tr('weekly'), style: const TextStyle(fontSize: 14)),
                          value: RepeatType.weekly,
                          groupValue: repeatType,
                          onChanged: (v) => setDialogState(() => repeatType = v!),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),

                  // 날짜/요일 선택
                  if (repeatType == RepeatType.monthly) ...[
                    Text(loc.tr('dayOfMonth'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(dialogContext).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: dayOfMonth,
                          items: List.generate(31, (i) => i + 1)
                              .map((d) => DropdownMenuItem(value: d, child: Text(loc.formatDayOfMonth(d))))
                              .toList(),
                          onChanged: (v) => setDialogState(() => dayOfMonth = v!),
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(loc.tr('dayOfWeek'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(dialogContext).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: dayOfWeek,
                          items: [
                            DropdownMenuItem(value: 0, child: Text(loc.tr('monday'))),
                            DropdownMenuItem(value: 1, child: Text(loc.tr('tuesday'))),
                            DropdownMenuItem(value: 2, child: Text(loc.tr('wednesday'))),
                            DropdownMenuItem(value: 3, child: Text(loc.tr('thursday'))),
                            DropdownMenuItem(value: 4, child: Text(loc.tr('friday'))),
                            DropdownMenuItem(value: 5, child: Text(loc.tr('saturday'))),
                            DropdownMenuItem(value: 6, child: Text(loc.tr('sunday'))),
                          ],
                          onChanged: (v) => setDialogState(() => dayOfWeek = v!),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(loc.tr('cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amount = int.tryParse(amountController.text);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.tr('numberOnlyError'))),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext);

                  if (isEdit) {
                    // RecurringExpenseProvider의 update 메서드 사용
                    final updated = existing.copyWith(
                      budgetId: selectedBudgetId,
                      subBudgetId: selectedSubBudgetId,
                      amount: amount,
                      memo: memoController.text.isEmpty ? null : memoController.text,
                      repeatType: repeatType,
                      dayOfWeek: repeatType == RepeatType.weekly ? dayOfWeek : null,
                      dayOfMonth: repeatType == RepeatType.monthly ? dayOfMonth : null,
                    );
                    await recurringProvider.update(updated);
                  } else {
                    // RecurringExpenseProvider의 add 메서드 사용
                    await recurringProvider.add(
                      budgetId: selectedBudgetId!,
                      subBudgetId: selectedSubBudgetId,
                      amount: amount,
                      memo: memoController.text.isEmpty ? null : memoController.text,
                      repeatType: repeatType,
                      dayOfWeek: repeatType == RepeatType.weekly ? dayOfWeek : null,
                      dayOfMonth: repeatType == RepeatType.monthly ? dayOfMonth : null,
                    );
                  }
                },
                child: Text(loc.tr('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  // 삭제 다이얼로그 - RecurringExpenseProvider의 delete 메서드 사용
  void _showDeleteDialog(BuildContext context, RecurringExpense recurring, RecurringExpenseProvider recurringProvider, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.tr('deleteConfirm')),
        content: Text(loc.tr('deleteRecurringConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // RecurringExpenseProvider의 delete 메서드 사용
              await recurringProvider.delete(recurring.id);
            },
            child: Text(loc.tr('delete'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
