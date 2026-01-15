content = '''import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../app_localizations.dart';
import '../providers/budget_provider.dart';
import '../providers/settings_provider.dart';
import '../services/markdown_export_service.dart';
import '../services/ai_analysis_service.dart';

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});
  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  int? touchedBudgetIndex;
  int? touchedExpenseIndex;
  String? selectedBudgetId;
  int? touchedSubBudgetIndex;

  final List<Color> chartColors = [
    const Color(0xFF6366F1), const Color(0xFF22C55E), const Color(0xFFF59E0B),
    const Color(0xFFEF4444), const Color(0xFF8B5CF6), const Color(0xFF06B6D4),
    const Color(0xFFEC4899), const Color(0xFF14B8A6), const Color(0xFFF97316),
    const Color(0xFF3B82F6), const Color(0xFF84CC16), const Color(0xFFD946EF),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Consumer2<BudgetProvider, SettingsProvider>(
      builder: (context, provider, settings, child) {
        final budgets = provider.currentBudgets;

        if (budgets.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text('\\${provider.currentYear}. \\${provider.currentMonth} \\${loc.tr('statsTab')}')),
            body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.pie_chart_outline, size: 64, color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(loc.tr('addBudgetFirst'), style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.outline)),
            ])),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text('\\${provider.currentYear}. \\${provider.currentMonth} \\${loc.tr('statsTab')}')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.tr('budgetAllocation'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildBudgetPieChart(budgets, provider),
                const SizedBox(height: 24),

                Text(loc.tr('actualUsage'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildExpensePieChart(budgets, provider),
                const SizedBox(height: 24),

                Text(loc.tr('subBudgetAnalysis'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildBudgetSelector(budgets),
                if (selectedBudgetId != null) ...[
                  const SizedBox(height: 16),
                  _buildSubBudgetPieChart(provider),
                ],
                const SizedBox(height: 24),

                // AI 분석 버튼
                _buildAiAnalysisButton(context, provider, settings),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  // AI 분석 버튼
  Widget _buildAiAnalysisButton(BuildContext context, BudgetProvider provider, SettingsProvider settings) {
    final loc = context.loc;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showAiAnalysisDialog(context, provider, settings),
        icon: const Icon(Icons.auto_awesome),
        label: Text(loc.tr('aiAnalysis')),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }

  // AI 분석 다이얼로그
  void _showAiAnalysisDialog(BuildContext context, BudgetProvider provider, SettingsProvider settings) {
    final loc = context.loc;
    DateTime startDate = DateTime(provider.currentYear, provider.currentMonth, 1);
    DateTime endDate = DateTime(provider.currentYear, provider.currentMonth + 1, 0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(loc.tr('aiAnalysis')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // API 키 입력
              Text(loc.tr('geminiApiKey'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: settings.geminiApiKey),
                decoration: InputDecoration(
                  hintText: loc.tr('enterApiKey'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                obscureText: true,
                onChanged: (value) => settings.setGeminiApiKey(value),
              ),
              const SizedBox(height: 16),

              // 기간 선택
              Text(loc.tr('selectPeriod'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setDialogState(() => startDate = picked);
                      },
                      child: Text(DateFormat('yyyy-MM-dd').format(startDate)),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('~')),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setDialogState(() => endDate = picked);
                      },
                      child: Text(DateFormat('yyyy-MM-dd').format(endDate)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _requestAiAnalysis(context, provider, settings, startDate, endDate);
              },
              child: Text(loc.tr('requestAnalysis')),
            ),
          ],
        ),
      ),
    );
  }

  // AI 분석 요청
  Future<void> _requestAiAnalysis(
    BuildContext context,
    BudgetProvider provider,
    SettingsProvider settings,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final loc = context.loc;

    // 로딩 다이얼로그
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(loc.tr('analyzing')),
          ],
        ),
      ),
    );

    try {
      // 마크다운 데이터 생성
      final mdService = MarkdownExportService(
        language: settings.language,
        currency: settings.currency,
      );

      // 기간 내 데이터 필터링
      final expenses = provider.currentExpenses.where((e) =>
        e.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
        e.date.isBefore(endDate.add(const Duration(days: 1)))
      ).toList();

      final markdownData = mdService.generateMarkdown(
        budgets: provider.currentBudgets,
        subBudgets: provider.currentSubBudgets,
        expenses: expenses,
        startDate: startDate,
        endDate: endDate,
        getTotalExpense: provider.getTotalExpense,
        getSubBudgetExpense: provider.getSubBudgetExpense,
      );

      // AI 분석 요청
      final aiService = AiAnalysisService(
        apiKey: settings.geminiApiKey,
        language: settings.language,
      );

      final result = await aiService.analyze(markdownData);

      // 로딩 다이얼로그 닫기
      if (context.mounted) Navigator.pop(context);

      // 결과 표시
      if (context.mounted) {
        if (result.error != null) {
          _showErrorDialog(context, result.error!);
        } else {
          _showAnalysisResultDialog(context, result, settings.language);
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) _showErrorDialog(context, e.toString());
    }
  }

  // 에러 다이얼로그
  void _showErrorDialog(BuildContext context, String message) {
    final loc = context.loc;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Text(loc.tr('error')),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.tr('confirm')),
          ),
        ],
      ),
    );
  }

  // 분석 결과 다이얼로그
  void _showAnalysisResultDialog(BuildContext context, AiAnalysisResponse result, String language) {
    final loc = context.loc;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amber),
            const SizedBox(width: 8),
            Text(loc.tr('analysisResult')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 요약
                _buildResultSection(loc.tr('summary'), result.summary, Icons.summarize),
                const Divider(),

                // 인사이트
                if (result.insights.isNotEmpty) ...[
                  _buildResultListSection(loc.tr('insights'), result.insights, Icons.lightbulb, Colors.amber),
                  const Divider(),
                ],

                // 경고
                if (result.warnings.isNotEmpty) ...[
                  _buildResultListSection(loc.tr('warnings'), result.warnings, Icons.warning, Colors.orange),
                  const Divider(),
                ],

                // 제안
                if (result.suggestions.isNotEmpty) ...[
                  _buildResultListSection(loc.tr('suggestions'), result.suggestions, Icons.tips_and_updates, Colors.green),
                  const Divider(),
                ],

                // 패턴 분석
                _buildPatternSection(loc, result.pattern),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.tr('confirm')),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        Text(content, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildResultListSection(String title, List<String> items, IconData icon, Color iconColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 13)),
              Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
            ],
          ),
        )),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPatternSection(AppLocalizations loc, SpendingPattern pattern) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.analytics, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(loc.tr('spendingPattern'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        _buildPatternRow(loc.tr('mainCategory'), pattern.mainCategory),
        _buildPatternRow(loc.tr('spendingTrend'), _getTrendText(pattern.spendingTrend, loc)),
        _buildPatternRow(loc.tr('savingPotential'), context.formatCurrency(pattern.savingPotential)),
        _buildPatternRow(loc.tr('riskLevel'), _getRiskText(pattern.riskLevel, loc)),
      ],
    );
  }

  Widget _buildPatternRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getTrendText(String trend, AppLocalizations loc) {
    switch (trend) {
      case 'increasing': return loc.tr('trendIncreasing');
      case 'decreasing': return loc.tr('trendDecreasing');
      case 'stable': return loc.tr('trendStable');
      default: return trend;
    }
  }

  String _getRiskText(String risk, AppLocalizations loc) {
    switch (risk) {
      case 'low': return loc.tr('riskLow');
      case 'medium': return loc.tr('riskMedium');
      case 'high': return loc.tr('riskHigh');
      default: return risk;
    }
  }

  Widget _buildBudgetPieChart(List budgets, BudgetProvider provider) {
    final loc = context.loc;
    final totalBudget = provider.totalBudget;
    if (totalBudget == 0) return Center(child: Text(loc.tr('noBudget')));

    return Container(
      height: 250,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                        touchedBudgetIndex = null;
                        return;
                      }
                      touchedBudgetIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sections: budgets.asMap().entries.map((entry) {
                  final index = entry.key;
                  final budget = entry.value;
                  final isTouched = index == touchedBudgetIndex;
                  final percentage = (budget.amount / totalBudget * 100);
                  return PieChartSectionData(
                    color: chartColors[index % chartColors.length],
                    value: budget.amount.toDouble(),
                    title: isTouched ? '\\${budget.name}\\n\\${context.formatCurrency(budget.amount)}' : '\\${percentage.toStringAsFixed(0)}%',
                    radius: isTouched ? 90 : 80,
                    titleStyle: TextStyle(fontSize: isTouched ? 12 : 11, fontWeight: FontWeight.bold, color: Colors.white),
                    titlePositionPercentageOffset: 0.55,
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: budgets.asMap().entries.map((entry) {
              final index = entry.key;
              final budget = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: chartColors[index % chartColors.length], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text(budget.name, style: const TextStyle(fontSize: 12)),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensePieChart(List budgets, BudgetProvider provider) {
    final loc = context.loc;
    int totalExpense = 0;
    final expenseData = <Map<String, dynamic>>[];
    for (var budget in budgets) {
      final expense = provider.getTotalExpense(budget.id);
      if (expense > 0) {
        expenseData.add({'name': budget.name, 'amount': expense, 'budget': budget});
        totalExpense += expense;
      }
    }

    if (totalExpense == 0) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3)),
        ),
        child: Center(child: Text(loc.tr('noExpense'), style: TextStyle(color: Theme.of(context).colorScheme.outline))),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                        touchedExpenseIndex = null;
                        return;
                      }
                      touchedExpenseIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sections: expenseData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  final isTouched = index == touchedExpenseIndex;
                  final percentage = (data['amount'] / totalExpense * 100);
                  return PieChartSectionData(
                    color: chartColors[index % chartColors.length],
                    value: data['amount'].toDouble(),
                    title: isTouched ? '\\${data['name']}\\n\\${context.formatCurrency(data['amount'])}' : '\\${percentage.toStringAsFixed(0)}%',
                    radius: isTouched ? 90 : 80,
                    titleStyle: TextStyle(fontSize: isTouched ? 12 : 11, fontWeight: FontWeight.bold, color: Colors.white),
                    titlePositionPercentageOffset: 0.55,
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: expenseData.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: chartColors[index % chartColors.length], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text(data['name'], style: const TextStyle(fontSize: 12)),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSelector(List budgets) {
    final loc = context.loc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedBudgetId,
          hint: Text(loc.tr('selectBudget')),
          items: budgets.map((b) => DropdownMenuItem<String>(value: b.id, child: Text(b.name))).toList(),
          onChanged: (value) => setState(() => selectedBudgetId = value),
        ),
      ),
    );
  }

  Widget _buildSubBudgetPieChart(BudgetProvider provider) {
    final loc = context.loc;
    final subBudgets = provider.getSubBudgets(selectedBudgetId!);
    if (subBudgets.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3)),
        ),
        child: Center(child: Text(loc.tr('noSubBudget'), style: TextStyle(color: Theme.of(context).colorScheme.outline))),
      );
    }

    int totalSubExpense = 0;
    final subExpenseData = <Map<String, dynamic>>[];
    for (var sub in subBudgets) {
      final expense = provider.getSubBudgetExpense(sub.id);
      subExpenseData.add({'name': sub.name, 'budget': sub.amount, 'expense': expense});
      totalSubExpense += expense;
    }

    return Container(
      height: 280,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(loc.tr('subBudgetUsage'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Expanded(
            child: totalSubExpense == 0
              ? Center(child: Text(loc.tr('noExpense'), style: TextStyle(color: Theme.of(context).colorScheme.outline)))
              : Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                  touchedSubBudgetIndex = null;
                                  return;
                                }
                                touchedSubBudgetIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          sections: subExpenseData.asMap().entries.where((e) => e.value['expense'] > 0).map((entry) {
                            final index = entry.key;
                            final data = entry.value;
                            final isTouched = index == touchedSubBudgetIndex;
                            final percentage = (data['expense'] / totalSubExpense * 100);
                            return PieChartSectionData(
                              color: chartColors[index % chartColors.length],
                              value: data['expense'].toDouble(),
                              title: isTouched ? '\\${data['name']}\\n\\${context.formatCurrency(data['expense'])}' : '\\${percentage.toStringAsFixed(0)}%',
                              radius: isTouched ? 80 : 70,
                              titleStyle: TextStyle(fontSize: isTouched ? 11 : 10, fontWeight: FontWeight.bold, color: Colors.white),
                              titlePositionPercentageOffset: 0.55,
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: subExpenseData.asMap().entries.map((entry) {
                        final index = entry.key;
                        final data = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: chartColors[index % chartColors.length], borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 6),
                            Text(data['name'], style: const TextStyle(fontSize: 11)),
                          ]),
                        );
                      }).toList(),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}
'''

with open('C:/SY/app/budget_app/lib/screens/stats_tab.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('stats_tab.dart updated')
