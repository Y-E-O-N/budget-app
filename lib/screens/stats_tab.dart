import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../app_localizations.dart';
import '../providers/budget_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/analysis_provider.dart';
import '../providers/trend_provider.dart';
import '../services/ai_analysis_service.dart';
import '../constants/app_constants.dart';
import '../utils/format_utils.dart';
import 'analysis_result_screen.dart';  // #26: 분석 결과 전용 화면

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

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});
  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Consumer4<BudgetProvider, SettingsProvider, AnalysisProvider, TrendProvider>(
      builder: (context, provider, settings, analysis, trend, child) {
        final budgets = provider.currentBudgets;

        if (budgets.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              // #12: 날짜 형식 변경 + 월 네비게이션
              title: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => provider.previousMonth()),
                Text('${provider.currentYear}년 ${provider.currentMonth}월', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => provider.nextMonth()),
              ]),
            ),
            body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.table_chart_outlined, size: 64, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(loc.tr('addBudgetFirst'), style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.outline)),
            ])),
          );
        }

        return Scaffold(
          appBar: AppBar(
            // #12: 날짜 형식 변경 + 월 네비게이션
            title: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => provider.previousMonth()),
              Text('${provider.currentYear}년 ${provider.currentMonth}월', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => provider.nextMonth()),
            ]),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: loc.tr('currentStatus')),
                Tab(text: loc.tr('trend')),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildCurrentStatusTab(context, budgets, provider, settings, analysis),
              _buildTrendTab(context, trend),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // 현황 탭 (스프레드시트 스타일)
  // =========================================================================
  Widget _buildCurrentStatusTab(BuildContext context, List budgets, BudgetProvider provider, SettingsProvider settings, AnalysisProvider analysis) {
    final loc = context.loc;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 예산 배분 테이블
          _buildSectionTitle(loc.tr('budgetAllocation')),
          _buildBudgetAllocationTable(context, budgets, provider),
          const SizedBox(height: 16),

          // 실제 사용 테이블
          _buildSectionTitle(loc.tr('actualUsage')),
          _buildActualUsageTable(context, budgets, provider),
          const SizedBox(height: 16),

          // AI 분석 버튼
          _buildAiAnalysisButton(context, provider, settings, analysis),
          const SizedBox(height: 16),

          // #30: 분석 상태 배너를 하단에 표시
          _buildAnalysisStatusBanner(context, analysis, settings.language),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  // 예산 배분 테이블
  Widget _buildBudgetAllocationTable(BuildContext context, List budgets, BudgetProvider provider) {
    final loc = context.loc;
    final totalBudget = provider.totalBudget;
    final border = BorderSide(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth),
      ),
      child: Column(
        children: [
          // 헤더
          Table(
            border: TableBorder(verticalInside: border),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(0.8),  // #22: 비율 열 너비 줄임
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: _SheetStyle.headerBg(context)),
                children: [
                  _buildCell(loc.tr('budgetName'), context, isHeader: true, align: TextAlign.center),  // #19: 중앙 정렬
                  _buildCell(loc.tr('budget'), context, isHeader: true, align: TextAlign.center),  // #19: 중앙 정렬
                  _buildCell(loc.tr('ratio'), context, isHeader: true, align: TextAlign.center),  // #19: 중앙 정렬
                ],
              ),
            ],
          ),
          // 데이터 행
          ...budgets.asMap().entries.map((entry) {
            final index = entry.key;
            final budget = entry.value;
            final percentage = totalBudget > 0 ? (budget.amount / totalBudget * 100) : 0.0;
            return Table(
              border: TableBorder(verticalInside: border, top: border),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(0.8),  // #22: 비율 열 너비 줄임
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: index % 2 == 0 ? _SheetStyle.evenRowBg(context) : _SheetStyle.oddRowBg(context)),
                  children: [
                    _buildCell(budget.name, context),
                    _buildCell(context.formatCurrency(budget.amount), context, align: TextAlign.right),
                    _buildCell('${percentage.toStringAsFixed(1)}%', context, align: TextAlign.center),  // #19: 중앙 정렬
                  ],
                ),
              ],
            );
          }),
          // 합계 행
          Table(
            border: TableBorder(verticalInside: border, top: border),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(0.8),  // #22: 비율 열 너비 줄임
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: _SheetStyle.headerBg(context)),
                children: [
                  _buildCell(loc.tr('total'), context, isHeader: true, align: TextAlign.center),  // #19: 중앙 정렬
                  _buildCell(context.formatCurrency(totalBudget), context, isHeader: true, align: TextAlign.right),
                  _buildCell('100%', context, isHeader: true, align: TextAlign.center),  // #19: 중앙 정렬
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 실제 사용 테이블
  Widget _buildActualUsageTable(BuildContext context, List budgets, BudgetProvider provider) {
    final loc = context.loc;
    final border = BorderSide(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth);

    int totalBudget = 0;
    int totalExpense = 0;
    for (var b in budgets) {
      totalBudget += b.amount as int;
      totalExpense += provider.getTotalExpense(b.id);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth),
      ),
      child: Column(
        children: [
          // 헤더 (#19: 중앙 정렬, #22: 비율 열 너비 줄임)
          Table(
            border: TableBorder(verticalInside: border),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(0.8),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: _SheetStyle.headerBg(context)),
                children: [
                  _buildCell(loc.tr('budgetName'), context, isHeader: true, align: TextAlign.center),
                  _buildCell(loc.tr('used'), context, isHeader: true, align: TextAlign.center),
                  _buildCell(loc.tr('remaining'), context, isHeader: true, align: TextAlign.center),
                  _buildCell(loc.tr('ratio'), context, isHeader: true, align: TextAlign.center),
                ],
              ),
            ],
          ),
          // 데이터 행
          ...budgets.asMap().entries.map((entry) {
            final index = entry.key;
            final budget = entry.value;
            final expense = provider.getTotalExpense(budget.id);
            final remaining = budget.amount - expense;
            final usageRate = budget.amount > 0 ? (expense / budget.amount * 100) : 0.0;
            final isOver = remaining < 0;

            return Table(
              border: TableBorder(verticalInside: border, top: border),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(0.8),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: index % 2 == 0 ? _SheetStyle.evenRowBg(context) : _SheetStyle.oddRowBg(context)),
                  children: [
                    _buildCell(budget.name, context),
                    _buildCell(context.formatCurrency(expense), context, align: TextAlign.right),
                    _buildCell(
                      context.formatCurrency(remaining),
                      context,
                      align: TextAlign.right,
                      textColor: isOver ? Theme.of(context).colorScheme.error : null,
                      bold: isOver,
                    ),
                    _buildCell(
                      '${usageRate.toStringAsFixed(0)}%',
                      context,
                      align: TextAlign.center,
                      textColor: usageRate > 100 ? Theme.of(context).colorScheme.error : usageRate > 80 ? Colors.orange : null,
                    ),
                  ],
                ),
              ],
            );
          }),
          // 합계 행
          Table(
            border: TableBorder(verticalInside: border, top: border),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(0.8),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: _SheetStyle.headerBg(context)),
                children: [
                  _buildCell(loc.tr('total'), context, isHeader: true, align: TextAlign.center),
                  _buildCell(context.formatCurrency(totalExpense), context, isHeader: true, align: TextAlign.right),
                  _buildCell(
                    context.formatCurrency(totalBudget - totalExpense),
                    context,
                    isHeader: true,
                    align: TextAlign.right,
                    textColor: totalBudget - totalExpense < 0 ? Theme.of(context).colorScheme.error : null,
                  ),
                  _buildCell(
                    totalBudget > 0 ? '${(totalExpense / totalBudget * 100).toStringAsFixed(0)}%' : '0%',
                    context,
                    isHeader: true,
                    align: TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCell(String text, BuildContext context, {
    bool isHeader = false,
    TextAlign align = TextAlign.left,
    Color? textColor,
    bool bold = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _SheetStyle.cellPaddingH, vertical: _SheetStyle.cellPaddingV),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? _SheetStyle.headerFontSize : _SheetStyle.fontSize,
          fontWeight: isHeader || bold ? FontWeight.w600 : FontWeight.normal,
          color: textColor ?? (isHeader ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface),
        ),
        textAlign: align,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // =========================================================================
  // 트렌드 탭 (스프레드시트 + 차트)
  // =========================================================================
  Widget _buildTrendTab(BuildContext context, TrendProvider trend) {
    final loc = context.loc;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 전월 대비 증감 테이블
          _buildMomChangeTable(context, trend),
          const SizedBox(height: 16),

          // 월별 지출 추이 테이블
          _buildSectionTitle(loc.tr('monthlyTrend')),
          _buildMonthlyTrendTable(context, trend),
          const SizedBox(height: 16),

          // 라인 차트
          _buildMonthlyTrendChart(context, trend),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // 전월 대비 증감 테이블
  Widget _buildMomChangeTable(BuildContext context, TrendProvider trend) {
    final loc = context.loc;
    final momData = trend.getMonthOverMonthData();
    final change = momData.changePercent;
    final currentExpense = momData.currentExpense;
    final prevExpense = momData.previousExpense;
    final diff = currentExpense - prevExpense;
    final border = BorderSide(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth),
      ),
      child: Table(
        border: TableBorder(verticalInside: border, horizontalInside: border),
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
        },
        children: [
          // 헤더
          TableRow(
            decoration: BoxDecoration(color: _SheetStyle.headerBg(context)),
            children: [
              _buildCell(loc.tr('lastMonth'), context, isHeader: true, align: TextAlign.center),
              _buildCell(loc.tr('thisMonth'), context, isHeader: true, align: TextAlign.center),
              _buildCell(loc.tr('difference'), context, isHeader: true, align: TextAlign.center),
              _buildCell(loc.tr('changeRate'), context, isHeader: true, align: TextAlign.center),
            ],
          ),
          // 데이터
          TableRow(
            decoration: BoxDecoration(color: _SheetStyle.evenRowBg(context)),
            children: [
              _buildCell(context.formatCurrency(prevExpense), context, align: TextAlign.center),
              _buildCell(context.formatCurrency(currentExpense), context, align: TextAlign.center),
              _buildCell(
                '${diff >= 0 ? '+' : ''}${context.formatCurrency(diff)}',
                context,
                align: TextAlign.center,
                textColor: diff > 0 ? Theme.of(context).colorScheme.error : diff < 0 ? Colors.green : null,
                bold: true,
              ),
              _buildCell(
                '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                context,
                align: TextAlign.center,
                textColor: change > 0 ? Theme.of(context).colorScheme.error : change < 0 ? Colors.green : null,
                bold: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 월별 지출 추이 테이블
  Widget _buildMonthlyTrendTable(BuildContext context, TrendProvider trend) {
    final loc = context.loc;
    final trendData = trend.getMonthlyTrend(AppConstants.trendMonthsDefault);
    if (trendData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: _SheetStyle.borderColor(context))),
        child: Center(child: Text(loc.tr('noExpense'))),
      );
    }

    final border = BorderSide(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth),
      ),
      child: Column(
        children: [
          // 헤더
          Table(
            border: TableBorder(verticalInside: border),
            children: [
              TableRow(
                decoration: BoxDecoration(color: _SheetStyle.headerBg(context)),
                children: trendData.map((d) =>
                  _buildCell(FormatUtils.formatMonth(d.month), context, isHeader: true, align: TextAlign.center)
                ).toList(),
              ),
            ],
          ),
          // 데이터
          Table(
            border: TableBorder(verticalInside: border, top: border),
            children: [
              TableRow(
                decoration: BoxDecoration(color: _SheetStyle.evenRowBg(context)),
                children: trendData.map((d) =>
                  _buildCell(d.expense > 0 ? FormatUtils.formatAmountShort(d.expense) : '-', context, align: TextAlign.center)  // 데이터 없으면 '-' 표시
                ).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 월별 지출 추이 라인 차트
  Widget _buildMonthlyTrendChart(BuildContext context, TrendProvider trend) {
    final trendData = trend.getMonthlyTrend(AppConstants.trendMonthsDefault);
    if (trendData.isEmpty) return const SizedBox.shrink();

    final maxExpense = trendData.map((d) => d.expense).reduce((a, b) => a > b ? a : b);
    final maxY = maxExpense > 0 ? (maxExpense * 1.2).toDouble() : 100.0;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        border: Border.all(color: _SheetStyle.borderColor(context)),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) => FlLine(color: _SheetStyle.borderColor(context), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(FormatUtils.formatAmountShort(value.toInt()), style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,  // #23: 숫자 중복 방지
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= trendData.length || value != index.toDouble()) return const SizedBox.shrink();  // #23: 정수 인덱스만 표시
                  return Text('${trendData[index].month}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline));
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (trendData.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(context.formatCurrency(spot.y.toInt()), const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12));
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: trendData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.expense.toDouble())).toList(),
              isCurved: false,  // #24: 직선 연결
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 5,
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 분석 관련 (기존 유지)
  // =========================================================================
  Widget _buildAnalysisStatusBanner(BuildContext context, AnalysisProvider analysis, String language) {
    final loc = context.loc;

    if (analysis.status == AnalysisStatus.running) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
        child: Row(children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
          const SizedBox(width: 12),
          Expanded(child: Text(loc.tr('analysisInProgress'), style: const TextStyle(color: Colors.orange, fontSize: 13))),
          TextButton(onPressed: () => analysis.cancelAnalysis(), child: Text(loc.tr('cancel'), style: const TextStyle(color: Colors.orange, fontSize: 12))),
        ]),
      );
    }

    if (analysis.status == AnalysisStatus.completed && analysis.hasUnreadResult && analysis.currentRecord != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
        child: Row(children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(loc.tr('analysisComplete'), style: const TextStyle(color: Colors.green, fontSize: 13))),
          TextButton(
            onPressed: () { analysis.markResultAsRead(); _showAnalysisResultDialogWithRecord(context, analysis.currentRecord!, language); },
            child: Text(loc.tr('viewResult'), style: const TextStyle(color: Colors.green, fontSize: 12)),
          ),
        ]),
      );
    }

    if (analysis.status == AnalysisStatus.cancelled) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), border: Border.all(color: Colors.grey.withValues(alpha: 0.3))),
        child: Row(children: [
          const Icon(Icons.cancel, color: Colors.grey, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(loc.tr('analysisCancelled'), style: const TextStyle(color: Colors.grey, fontSize: 13))),
          IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.grey), onPressed: () => analysis.reset()),
        ]),
      );
    }

    if (analysis.status == AnalysisStatus.error) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
        child: Row(children: [
          const Icon(Icons.error, color: Colors.red, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(analysis.error ?? loc.tr('error'), style: const TextStyle(color: Colors.red, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
          IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.red), onPressed: () => analysis.reset()),
        ]),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildAiAnalysisButton(BuildContext context, BudgetProvider provider, SettingsProvider settings, AnalysisProvider analysis) {
    final loc = context.loc;
    final isRunning = analysis.isRunning;
    final hasRecord = analysis.currentRecord != null;
    final hasHistory = analysis.history.isNotEmpty;
    final border = BorderSide(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth);

    return Container(
      decoration: BoxDecoration(border: Border.all(color: _SheetStyle.borderColor(context))),
      child: Column(
        children: [
          // 헤더
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: _SheetStyle.cellPaddingH, vertical: _SheetStyle.cellPaddingV),
            decoration: BoxDecoration(color: _SheetStyle.headerBg(context), border: Border(bottom: border)),
            child: Text(loc.tr('aiAnalysis'), style: TextStyle(fontSize: _SheetStyle.headerFontSize, fontWeight: FontWeight.w600)),
          ),
          // 버튼들
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isRunning ? null : () => _showAiAnalysisDialog(context, provider, settings, analysis),
                    icon: isRunning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(isRunning ? loc.tr('analyzing') : loc.tr('requestAnalysis'), style: const TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
                  ),
                ),
                if (hasRecord) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () { analysis.markResultAsRead(); _showAnalysisResultDialogWithRecord(context, analysis.currentRecord!, settings.language); },
                      icon: const Icon(Icons.description, size: 18),
                      label: Text(loc.tr('viewAnalysisResult'), style: const TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                    ),
                  ),
                ],
                if (hasHistory) ...[
                  const SizedBox(height: 12),
                  // 분석 이력 인라인 리스트
                  Row(children: [
                    Icon(Icons.history, size: 16, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(width: 6),
                    Text('${loc.tr('analysisHistory')} (${analysis.history.length})', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (analysis.history.length > 1)
                      GestureDetector(
                        onTap: () => _showClearHistoryConfirm(context, analysis),
                        child: Text(loc.tr('clearAll'), style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error)),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  ...analysis.history.map((record) {
                    final dateFormat = DateFormat('yyyy.MM.dd');
                    final isSelected = analysis.currentRecord == record;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Dismissible(
                          key: ValueKey(record.analyzedAt.toIso8601String()),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDeleteRecord(context, analysis, record),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Theme.of(context).colorScheme.error,
                            child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
                          ),
                          child: Material(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                                : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            child: InkWell(
                              onTap: () => _showAnalysisResultDialogWithRecord(context, record, settings.language),
                              onLongPress: () => _confirmDeleteRecord(context, analysis, record),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(children: [
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${dateFormat.format(record.startDate)} ~ ${dateFormat.format(record.endDate)}',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Theme.of(context).colorScheme.primary : null),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${loc.tr('analyzedAt')}: ${DateFormat('yyyy.MM.dd HH:mm').format(record.analyzedAt)}',
                                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                                      ),
                                    ],
                                  )),
                                  Icon(Icons.chevron_right, size: 20, color: Theme.of(context).colorScheme.outline),
                                ]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryConfirm(BuildContext context, AnalysisProvider analysis) {
    final loc = context.loc;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.tr('confirm')),
        content: Text(loc.tr('clearHistoryConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.tr('cancel'))),
          TextButton(onPressed: () async { await analysis.clearHistory(); if (ctx.mounted) Navigator.pop(ctx); }, child: Text(loc.tr('delete'), style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );
  }

  Future<bool> _confirmDeleteRecord(BuildContext context, AnalysisProvider analysis, AnalysisRecord record) async {
    final loc = context.loc;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.tr('deleteConfirm')),
        content: Text('${DateFormat('yyyy.MM.dd').format(record.startDate)} ~ ${DateFormat('yyyy.MM.dd').format(record.endDate)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(loc.tr('delete'), style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );
    if (confirmed == true) {
      await analysis.deleteRecord(record);
      return true;
    }
    return false;
  }

  void _showAiAnalysisDialog(BuildContext context, BudgetProvider provider, SettingsProvider settings, AnalysisProvider analysis) {
    final loc = context.loc;
    DateTime startDate = DateTime(provider.currentYear, provider.currentMonth, 1);
    DateTime endDate = DateTime(provider.currentYear, provider.currentMonth + 1, 0);
    String selectedTone = 'gentle';

    final toneOptions = [
      {'key': 'gentle', 'labelKey': 'toneGentle'},
      {'key': 'praise', 'labelKey': 'tonePraise'},
      {'key': 'factual', 'labelKey': 'toneFactual'},
      {'key': 'coach', 'labelKey': 'toneCoach'},
      {'key': 'humorous', 'labelKey': 'toneHumorous'},
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(loc.tr('aiAnalysis')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.tr('selectPeriod'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(context: dialogContext, initialDate: startDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (picked != null) setDialogState(() => startDate = picked);
                  },
                  child: Text(DateFormat('yyyy-MM-dd').format(startDate), style: const TextStyle(fontSize: 12)),
                )),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('~')),
                Expanded(child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(context: dialogContext, initialDate: endDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (picked != null) setDialogState(() => endDate = picked);
                  },
                  child: Text(DateFormat('yyyy-MM-dd').format(endDate), style: const TextStyle(fontSize: 12)),
                )),
              ]),
              const SizedBox(height: 16),
              Text(loc.tr('selectTone'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: Border.all(color: _SheetStyle.borderColor(dialogContext))),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    isDense: true,
                    value: selectedTone,
                    style: TextStyle(fontSize: 13, color: Theme.of(dialogContext).colorScheme.onSurface),
                    items: toneOptions.map((opt) => DropdownMenuItem<String>(value: opt['key'], child: Text(loc.tr(opt['labelKey']!)))).toList(),
                    onChanged: (value) { if (value != null) setDialogState(() => selectedTone = value); },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(loc.tr('cancel'))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                // #29: 잔여횟수 확인 후 분석 요청
                _showAnalysisConfirmDialog(context, provider, settings, analysis, startDate, endDate, selectedTone);
              },
              child: Text(loc.tr('requestAnalysis')),
            ),
          ],
        ),
      ),
    );
  }

  // #29: 잔여횟수 확인 다이얼로그
  void _showAnalysisConfirmDialog(BuildContext context, BudgetProvider provider, SettingsProvider settings, AnalysisProvider analysis, DateTime startDate, DateTime endDate, String tone) async {
    final loc = context.loc;
    final service = AiAnalysisService(language: settings.language);

    // 사용량 조회
    final usageResult = await service.getUsage();

    if (!context.mounted) return;

    usageResult.fold(
      onSuccess: (usage) {
        // 잔여횟수 표시 확인 다이얼로그
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Row(children: [
              Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(loc.tr('confirm')),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.tr('analysisConfirmMessage')),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: usage.remaining > 0
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    border: Border.all(
                      color: usage.remaining > 0 ? Colors.green : Colors.red,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        usage.remaining > 0 ? Icons.check_circle : Icons.warning,
                        color: usage.remaining > 0 ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${loc.tr('remainingAnalyses')}: ${usage.remaining}/${usage.limit}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: usage.remaining > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                if (usage.remaining == 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    loc.tr('noRemainingAnalyses'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(loc.tr('cancel'))),
              if (usage.remaining > 0)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _startBackgroundAnalysis(context, provider, settings, analysis, startDate, endDate, tone);
                  },
                  child: Text(loc.tr('requestAnalysis')),
                ),
            ],
          ),
        );
      },
      onFailure: (error) {
        // #32-33: 사용량 조회 실패 시 분석을 진행하지 않고 사용자에게 안내
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text(loc.tr('error')),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.tr('usageCheckFailed')),
                const SizedBox(height: 12),
                Text(
                  loc.tr('cannotProceedWithoutUsageCheck'),
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(loc.tr('confirm'))),
            ],
          ),
        );
      },
    );
  }

  void _startBackgroundAnalysis(BuildContext context, BudgetProvider provider, SettingsProvider settings, AnalysisProvider analysis, DateTime startDate, DateTime endDate, String tone) {
    final expenses = provider.currentExpenses.where((e) => e.date.isAfter(startDate.subtract(const Duration(days: 1))) && e.date.isBefore(endDate.add(const Duration(days: 1)))).toList();
    analysis.startAnalysis(language: settings.language, currency: settings.currency, budgets: provider.currentBudgets, subBudgets: provider.currentSubBudgets, expenses: expenses, startDate: startDate, endDate: endDate, getTotalExpense: provider.getTotalExpense, getSubBudgetExpense: provider.getSubBudgetExpense, tone: tone);
  }

  // #26: 분석 결과를 새 페이지로 표시
  void _showAnalysisResultDialogWithRecord(BuildContext context, AnalysisRecord record, String language) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AnalysisResultScreen(record: record, language: language)),
    );
  }

  String _getToneLabel(String tone, AppLocalizations loc) {
    switch (tone) {
      case 'gentle': return loc.tr('toneGentle');
      case 'praise': return loc.tr('tonePraise');
      case 'factual': return loc.tr('toneFactual');
      case 'coach': return loc.tr('toneCoach');
      case 'humorous': return loc.tr('toneHumorous');
      default: return tone;
    }
  }
}
