import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_localizations.dart';
import '../providers/settings_provider.dart';
import '../providers/analysis_provider.dart';
import 'budget_tab.dart';
import 'history_tab.dart';
import 'stats_tab.dart';
import 'settings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _tabs = const [BudgetTab(), HistoryTab(), StatsTab(), SettingsTab()];

  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsProvider, AnalysisProvider>(
      builder: (context, settings, analysis, child) {
        final loc = context.loc;
        // 분석 진행 중 또는 미확인 결과 있으면 배지 표시
        final showBadge = analysis.isRunning || analysis.hasUnreadResult;
        return Scaffold(
          body: _tabs[_currentIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            destinations: [
              NavigationDestination(icon: const Icon(Icons.account_balance_wallet_outlined), selectedIcon: const Icon(Icons.account_balance_wallet), label: loc.tr('budgetTab')),
              NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: loc.tr('historyTab')),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: showBadge,
                  backgroundColor: analysis.isRunning ? Colors.orange : Colors.red,
                  smallSize: 8,
                  child: const Icon(Icons.bar_chart_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: showBadge,
                  backgroundColor: analysis.isRunning ? Colors.orange : Colors.red,
                  smallSize: 8,
                  child: const Icon(Icons.bar_chart),
                ),
                label: loc.tr('statsTab'),
              ),
              NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: loc.tr('settingsTab')),
            ],
          ),
        );
      },
    );
  }
}
