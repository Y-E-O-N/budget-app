import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'models/budget.dart';
import 'models/sub_budget.dart';
import 'models/expense.dart';
import 'models/recurring_expense.dart';
import 'providers/budget_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/analysis_provider.dart';
import 'providers/trend_provider.dart';
import 'providers/recurring_expense_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await initializeDateFormatting();

  Hive.registerAdapter(BudgetAdapter());
  Hive.registerAdapter(SubBudgetAdapter());
  Hive.registerAdapter(ExpenseAdapter());
  Hive.registerAdapter(RecurringExpenseAdapter());
  Hive.registerAdapter(RepeatTypeAdapter());

  // 설정 Provider 초기화
  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  // 예산 Provider 초기화 (핵심 데이터)
  final budgetProvider = BudgetProvider();
  await budgetProvider.init();

  // 트렌드 Provider 초기화 (BudgetProvider 의존)
  final trendProvider = TrendProvider(budgetProvider);

  // 반복 지출 Provider 초기화
  final recurringExpenseProvider = RecurringExpenseProvider();
  await recurringExpenseProvider.init();

  // 분석 Provider 초기화
  final analysisProvider = AnalysisProvider();
  await analysisProvider.init();

  runApp(MyApp(
    settingsProvider: settingsProvider,
    budgetProvider: budgetProvider,
    trendProvider: trendProvider,
    recurringExpenseProvider: recurringExpenseProvider,
    analysisProvider: analysisProvider,
  ));
}

class MyApp extends StatelessWidget {
  final SettingsProvider settingsProvider;
  final BudgetProvider budgetProvider;
  final TrendProvider trendProvider;
  final RecurringExpenseProvider recurringExpenseProvider;
  final AnalysisProvider analysisProvider;

  const MyApp({
    super.key,
    required this.settingsProvider,
    required this.budgetProvider,
    required this.trendProvider,
    required this.recurringExpenseProvider,
    required this.analysisProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: budgetProvider),
        ChangeNotifierProvider.value(value: trendProvider),
        ChangeNotifierProvider.value(value: recurringExpenseProvider),
        ChangeNotifierProvider.value(value: analysisProvider),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          final seedColor = Color(settings.colorTheme);

          return MaterialApp(
            title: '가계부',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
              cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
              cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            themeMode: settings.themeMode,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(settings.fontSizeScale)),
                child: child!,
              );
            },
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
