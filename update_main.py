#!/usr/bin/env python3
# -*- coding: utf-8 -*-

content = r'''// =============================================================================
// main.dart - 앱의 진입점 (Entry Point)
// =============================================================================
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'models/budget.dart';
import 'models/sub_budget.dart';
import 'models/expense.dart';
import 'providers/budget_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(BudgetAdapter());
  Hive.registerAdapter(SubBudgetAdapter());
  Hive.registerAdapter(ExpenseAdapter());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()..init()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          final seedColor = Color(settings.colorTheme);

          return MaterialApp(
            title: '가계부',
            debugShowCheckedModeBanner: false,

            // 라이트 테마
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: seedColor,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            // 다크 테마
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: seedColor,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            // 테마 모드 (설정에서 지정)
            themeMode: settings.themeMode,

            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
'''

with open(r'C:\SY\app\budget_app\lib\main.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('main.dart updated')
