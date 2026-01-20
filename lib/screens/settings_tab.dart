import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_localizations.dart';
import '../providers/settings_provider.dart';
import '../providers/budget_provider.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import 'recurring_expense_screen.dart';
import 'widget_settings_screen.dart';

// =============================================================================
// 스프레드시트 스타일 상수
// =============================================================================
class _SheetStyle {
  static const double borderWidth = 1.0;
  static const double cellPaddingH = 12.0;
  static const double cellPaddingV = 14.0;
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

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final loc = context.loc;
        return Scaffold(
          appBar: AppBar(title: Text(loc.tr('settings'))),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                // 기본 설정
                _buildSettingsTable(
                  context: context,
                  title: loc.tr('basicSettings'),
                  rows: [
                    _buildCurrencyRow(context, settings, loc),
                    // #16: 시작요일 설정 숨김
                    // _buildStartDayRow(context, settings, loc),
                    _buildMonthStartDayRow(context, settings, loc),
                    _buildLanguageRow(context, settings, loc),
                  ],
                ),
                const SizedBox(height: 12),

                // 알림 설정
                _buildSettingsTable(
                  context: context,
                  title: loc.tr('notificationSettings'),
                  rows: [
                    _buildDailyReminderRow(context, settings, loc),
                    _buildBudgetAlertRow(context, settings, loc),
                  ],
                ),
                const SizedBox(height: 12),

                // 화면/테마
                _buildSettingsTable(
                  context: context,
                  title: loc.tr('displaySettings'),
                  rows: [
                    _buildThemeModeRow(context, settings, loc),
                    _buildFontSizeRow(context, settings, loc),
                    _buildColorThemeRow(context, settings, loc),
                  ],
                ),
                const SizedBox(height: 12),

                // 데이터 관리
                _buildSettingsTable(
                  context: context,
                  title: loc.tr('dataManagement'),
                  rows: [
                    _buildRecurringExpenseRow(context, loc),
                    _buildExportRow(context, settings, loc),
                    _buildImportRow(context, settings, loc),
                  ],
                ),
                const SizedBox(height: 12),

                // 기타
                _buildSettingsTable(
                  context: context,
                  title: loc.tr('others'),
                  rows: [
                    _buildWidgetSettingsRow(context, loc),
                    _buildAboutRow(context, loc),
                    _buildHelpRow(context, loc),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  // 설정 테이블 빌더
  Widget _buildSettingsTable({
    required BuildContext context,
    required String title,
    required List<_SettingRowData> rows,
  }) {
    final border = BorderSide(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _SheetStyle.borderColor(context), width: _SheetStyle.borderWidth),
      ),
      child: Column(
        children: [
          // 섹션 헤더
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: _SheetStyle.cellPaddingH, vertical: _SheetStyle.cellPaddingV),
            decoration: BoxDecoration(color: _SheetStyle.headerBg(context)),
            child: Text(
              title,
              style: TextStyle(
                fontSize: _SheetStyle.headerFontSize,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          // 설정 행들
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            return InkWell(
              onTap: row.onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: index % 2 == 0 ? _SheetStyle.evenRowBg(context) : _SheetStyle.oddRowBg(context),
                  border: Border(top: border),
                ),
                child: Row(
                  children: [
                    // 아이콘
                    Container(
                      width: 48,
                      padding: EdgeInsets.symmetric(vertical: _SheetStyle.cellPaddingV),
                      child: Icon(row.icon, size: 20, color: Theme.of(context).colorScheme.outline),
                    ),
                    Container(width: 1, height: 44, color: _SheetStyle.borderColor(context)),
                    // 설정명
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: _SheetStyle.cellPaddingH, vertical: _SheetStyle.cellPaddingV),
                        child: Text(row.label, style: TextStyle(fontSize: _SheetStyle.fontSize)),
                      ),
                    ),
                    Container(width: 1, height: 44, color: _SheetStyle.borderColor(context)),
                    // 현재 값
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: _SheetStyle.cellPaddingH, vertical: _SheetStyle.cellPaddingV),
                        child: Row(
                          children: [
                            if (row.leading != null) ...[row.leading!, const SizedBox(width: 8)],
                            Expanded(
                              child: Text(
                                row.value,
                                style: TextStyle(fontSize: _SheetStyle.fontSize, color: Theme.of(context).colorScheme.primary),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            if (row.trailing != null) ...[const SizedBox(width: 4), row.trailing!]
                            else const SizedBox(width: 4),
                            Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.outline),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // 기본 설정 행들
  _SettingRowData _buildCurrencyRow(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    final currencies = [
      {'symbol': '₩', 'name': '원 (KRW)'},
      {'symbol': '\$', 'name': 'Dollar'},
      {'symbol': '¥', 'name': '円 (JPY)'},
      {'symbol': '€', 'name': 'Euro'},
      {'symbol': '£', 'name': 'Pound'},
    ];
    final current = currencies.firstWhere((c) => c['symbol'] == settings.currency, orElse: () => currencies[0]);
    return _SettingRowData(
      icon: Icons.attach_money,
      label: loc.tr('currency'),
      value: current['name']!,
      onTap: () => _showCurrencyDialog(context, settings, currencies, loc),
    );
  }

  _SettingRowData _buildStartDayRow(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    final days = {
      'monday': loc.tr('monday'), 'tuesday': loc.tr('tuesday'), 'wednesday': loc.tr('wednesday'),
      'thursday': loc.tr('thursday'), 'friday': loc.tr('friday'), 'saturday': loc.tr('saturday'), 'sunday': loc.tr('sunday')
    };
    return _SettingRowData(
      icon: Icons.calendar_view_week,
      label: loc.tr('startDayOfWeek'),
      value: days[settings.startDayOfWeek] ?? loc.tr('monday'),
      onTap: () => _showStartDayDialog(context, settings, days, loc),
    );
  }

  _SettingRowData _buildMonthStartDayRow(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    return _SettingRowData(
      icon: Icons.calendar_today,
      label: loc.tr('monthStartDay'),
      value: '${settings.monthStartDay}',
      onTap: () => _showMonthStartDayDialog(context, settings, loc),
    );
  }

  _SettingRowData _buildLanguageRow(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    final languages = {'ko': '한국어', 'en': 'English', 'ja': '日本語'};
    return _SettingRowData(
      icon: Icons.language,
      label: loc.tr('language'),
      value: languages[settings.language] ?? '한국어',
      onTap: () => _showLanguageDialog(context, settings, languages, loc),
    );
  }

  // 알림 설정 행들
  _SettingRowData _buildDailyReminderRow(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    final timeStr = '${settings.dailyReminderHour.toString().padLeft(2, '0')}:${settings.dailyReminderMinute.toString().padLeft(2, '0')}';
    return _SettingRowData(
      icon: Icons.notifications,
      label: loc.tr('dailyReminder'),
      value: settings.dailyReminderEnabled ? timeStr : loc.tr('off'),
      trailing: Switch(
        value: settings.dailyReminderEnabled,
        onChanged: (value) async {
          if (value) {
            final granted = await settings.requestNotificationPermission();
            if (!granted) return;
            if (context.mounted) await _showTimePickerForReminder(context, settings, value);
          } else {
            settings.setDailyReminder(false);
          }
        },
      ),
      onTap: () async {
        if (settings.dailyReminderEnabled) {
          await _showTimePickerForReminder(context, settings, true);
        }
      },
    );
  }

  _SettingRowData _buildBudgetAlertRow(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    return _SettingRowData(
      icon: Icons.warning_amber,
      label: loc.tr('budgetAlert'),
      value: settings.budgetAlertEnabled ? '${settings.budgetAlertThreshold}%' : loc.tr('off'),
      trailing: Switch(
        value: settings.budgetAlertEnabled,
        onChanged: (value) async {
          if (value) {
            final granted = await settings.requestNotificationPermission();
            if (!granted) return;
            if (context.mounted) _showBudgetAlertThresholdDialog(context, settings, loc);
          } else {
            settings.setBudgetAlert(false);
          }
        },
      ),
      onTap: () {
        if (settings.budgetAlertEnabled) {
          _showBudgetAlertThresholdDialog(context, settings, loc);
        }
      },
    );
  }

  // 화면/테마 행들
  _SettingRowData _buildThemeModeRow(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    final modes = {'system': loc.tr('systemSetting'), 'light': loc.tr('lightMode'), 'dark': loc.tr('darkModeOption')};
    return _SettingRowData(
      icon: Icons.dark_mode,
      label: loc.tr('darkMode'),
      value: modes[settings.themeModeSetting] ?? loc.tr('systemSetting'),
      onTap: () => _showThemeModeDialog(context, settings, modes, loc),
    );
  }

  _SettingRowData _buildFontSizeRow(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    final sizes = {0.85: loc.tr('fontSmall'), 1.0: loc.tr('fontNormal'), 1.15: loc.tr('fontLarge'), 1.3: loc.tr('fontExtraLarge')};
    return _SettingRowData(
      icon: Icons.format_size,
      label: loc.tr('fontSize'),
      value: sizes[settings.fontSizeScale] ?? loc.tr('fontNormal'),
      onTap: () => _showFontSizeDialog(context, settings, sizes, loc),
    );
  }

  _SettingRowData _buildColorThemeRow(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    final colors = [
      {'color': 0xFF6366F1, 'name': loc.tr('indigo')},
      {'color': 0xFF22C55E, 'name': loc.tr('green')},
      {'color': 0xFF3B82F6, 'name': loc.tr('blue')},
      {'color': 0xFFEF4444, 'name': loc.tr('red')},
      {'color': 0xFFF59E0B, 'name': loc.tr('orange')},
      {'color': 0xFF8B5CF6, 'name': loc.tr('purple')},
      {'color': 0xFFEC4899, 'name': loc.tr('pink')},
      {'color': 0xFF14B8A6, 'name': loc.tr('teal')},
    ];
    final current = colors.firstWhere((c) => c['color'] == settings.colorTheme, orElse: () => colors[0]);
    return _SettingRowData(
      icon: Icons.palette,
      label: loc.tr('colorTheme'),
      value: current['name'] as String,
      leading: Container(width: 16, height: 16, decoration: BoxDecoration(color: Color(settings.colorTheme), borderRadius: BorderRadius.circular(2))),
      onTap: () => _showColorThemeDialog(context, settings, colors, loc),
    );
  }

  // 데이터 관리 행들
  _SettingRowData _buildRecurringExpenseRow(BuildContext context, AppLocalizations loc) {
    return _SettingRowData(
      icon: Icons.repeat,
      label: loc.tr('recurringExpense'),
      value: '',
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RecurringExpenseScreen())),
    );
  }

  _SettingRowData _buildExportRow(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    return _SettingRowData(
      icon: Icons.file_download,
      label: loc.tr('exportExcel'),
      value: '',
      onTap: () => _exportToExcel(context, settings, loc),
    );
  }

  _SettingRowData _buildImportRow(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    return _SettingRowData(
      icon: Icons.file_upload,
      label: loc.tr('importExcel'),
      value: '',
      onTap: () => _importFromExcel(context, settings, loc),
    );
  }

  // 기타 행들
  _SettingRowData _buildWidgetSettingsRow(BuildContext context, AppLocalizations loc) {
    return _SettingRowData(
      icon: Icons.widgets_outlined,
      label: loc.tr('widgetSettings'),
      value: '',
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WidgetSettingsScreen())),
    );
  }

  _SettingRowData _buildAboutRow(BuildContext context, AppLocalizations loc) {
    return _SettingRowData(
      icon: Icons.info_outline,
      label: loc.tr('appInfo'),
      value: 'v1.0.0',
      onTap: () => showAboutDialog(
        context: context,
        applicationName: loc.tr('appTitle'),
        applicationVersion: '1.0.0',
        applicationLegalese: '© 2025',
        children: [const SizedBox(height: 16), Text(loc.tr('appDesc'))],
      ),
    );
  }

  _SettingRowData _buildHelpRow(BuildContext context, AppLocalizations loc) {
    return _SettingRowData(
      icon: Icons.help_outline,
      label: loc.tr('help'),
      value: '',
      onTap: () => _showHelpDialog(context, loc),
    );
  }

  // =========================================================================
  // 다이얼로그들 (기존 유지)
  // =========================================================================

  void _showCurrencyDialog(BuildContext context, SettingsProvider settings, List<Map<String, String>> currencies, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(loc.tr('selectCurrency')),
        children: currencies.map((c) => RadioListTile<String>(
          title: Text(c['name']!),
          value: c['symbol']!,
          groupValue: settings.currency,
          onChanged: (value) { if (value != null) { settings.setCurrency(value); Navigator.pop(context); } },
        )).toList(),
      ),
    );
  }

  void _showStartDayDialog(BuildContext context, SettingsProvider settings, Map<String, String> days, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(loc.tr('selectStartDay')),
        children: days.entries.map((e) => RadioListTile<String>(
          title: Text(e.value),
          value: e.key,
          groupValue: settings.startDayOfWeek,
          onChanged: (value) { if (value != null) { settings.setStartDayOfWeek(value); Navigator.pop(context); } },
        )).toList(),
      ),
    );
  }

  void _showMonthStartDayDialog(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    int selectedDay = settings.monthStartDay;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(loc.tr('selectMonthStartDay')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.tr('monthStartDayDesc'), style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: Border.all(color: _SheetStyle.borderColor(context))),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedDay,
                    isExpanded: true,
                    items: List.generate(28, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                    onChanged: (value) { if (value != null) setState(() => selectedDay = value); },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.tr('cancel'))),
            FilledButton(onPressed: () { settings.setMonthStartDay(selectedDay); Navigator.pop(context); }, child: Text(loc.tr('confirm'))),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, SettingsProvider settings, Map<String, String> languages, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(loc.tr('selectLanguage')),
        children: languages.entries.map((e) => RadioListTile<String>(
          title: Text(e.value),
          value: e.key,
          groupValue: settings.language,
          onChanged: (value) { if (value != null) { settings.setLanguage(value); Navigator.pop(context); } },
        )).toList(),
      ),
    );
  }

  Future<void> _showTimePickerForReminder(BuildContext context, SettingsProvider settings, bool enabled) async {
    final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: settings.dailyReminderHour, minute: settings.dailyReminderMinute));
    if (time != null) await settings.setDailyReminder(enabled, hour: time.hour, minute: time.minute);
  }

  void _showBudgetAlertThresholdDialog(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    int threshold = settings.budgetAlertThreshold;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(loc.tr('budgetAlertThreshold')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$threshold%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Slider(value: threshold.toDouble(), min: 50, max: 100, divisions: 10, label: '$threshold%', onChanged: (value) => setState(() => threshold = value.round())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.tr('cancel'))),
            FilledButton(onPressed: () { settings.setBudgetAlert(true, threshold: threshold); Navigator.pop(context); }, child: Text(loc.tr('confirm'))),
          ],
        ),
      ),
    );
  }

  void _showThemeModeDialog(BuildContext context, SettingsProvider settings, Map<String, String> modes, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(loc.tr('selectThemeMode')),
        children: modes.entries.map((e) => RadioListTile<String>(
          title: Text(e.value),
          value: e.key,
          groupValue: settings.themeModeSetting,
          onChanged: (value) { if (value != null) { settings.setThemeMode(value); Navigator.pop(context); } },
        )).toList(),
      ),
    );
  }

  void _showFontSizeDialog(BuildContext context, SettingsProvider settings, Map<double, String> sizes, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(loc.tr('selectFontSize')),
        children: sizes.entries.map((e) => RadioListTile<double>(
          title: Text(e.value),
          value: e.key,
          groupValue: settings.fontSizeScale,
          onChanged: (value) { if (value != null) { settings.setFontSizeScale(value); Navigator.pop(context); } },
        )).toList(),
      ),
    );
  }

  void _showColorThemeDialog(BuildContext context, SettingsProvider settings, List<Map<String, dynamic>> colors, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(loc.tr('selectColorTheme')),
        children: colors.map((c) => ListTile(
          leading: Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: Color(c['color'] as int),
              borderRadius: BorderRadius.circular(4),
              border: settings.colorTheme == c['color'] ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
            ),
          ),
          title: Text(c['name'] as String),
          trailing: settings.colorTheme == c['color'] ? const Icon(Icons.check) : null,
          onTap: () { settings.setColorTheme(c['color'] as int); Navigator.pop(context); },
        )).toList(),
      ),
    );
  }

  Future<void> _exportToExcel(BuildContext context, SettingsProvider settings, AppLocalizations loc) async {
    final budgetProvider = context.read<BudgetProvider>();
    showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(content: Row(children: [const CircularProgressIndicator(), const SizedBox(width: 16), Text(loc.tr('exporting'))])));

    try {
      final exportService = ExportService(language: settings.language, currency: settings.currency);
      final success = await exportService.exportToExcel(
        budgets: budgetProvider.currentBudgets,
        subBudgets: budgetProvider.currentBudgets.expand((b) => budgetProvider.getSubBudgets(b.id)).toList(),
        expenses: budgetProvider.currentBudgets.expand((b) => budgetProvider.getExpenses(b.id)).toList(),
        year: budgetProvider.currentYear, month: budgetProvider.currentMonth,
        getTotalExpense: budgetProvider.getTotalExpense, getSubBudgetExpense: budgetProvider.getSubBudgetExpense,
      );
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? loc.tr('exportSuccess') : loc.tr('exportFailed')), backgroundColor: success ? Colors.green : Colors.red));
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.tr('exportFailed')), backgroundColor: Colors.red));
    }
  }

  Future<void> _importFromExcel(BuildContext context, SettingsProvider settings, AppLocalizations loc) async {
    final budgetProvider = context.read<BudgetProvider>();
    final importService = ImportService(language: settings.language);
    final parseResult = await importService.pickAndParse();
    final importData = parseResult.dataOrNull;

    if (importData == null) {
      if (context.mounted) {
        final errorMsg = parseResult.errorOrNull != null ? importService.getErrorMessage(parseResult.errorOrNull!) : loc.tr('importFailed');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
      }
      return;
    }

    if (importData.expenses.isEmpty && importData.budgets.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.tr('noDataToImport')), backgroundColor: Colors.orange));
      return;
    }

    int? targetYear, targetMonth;
    if (importData.expenses.isNotEmpty) {
      targetYear = importData.expenses.first.date.year;
      targetMonth = importData.expenses.first.date.month;
    }

    if (context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(loc.tr('importConfirm')),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(loc.tr('importSummary')), const SizedBox(height: 12),
            Text('• ${loc.tr('budget')}: ${importData.budgets.length}'),
            Text('• ${loc.tr('subBudget')}: ${importData.subBudgets.length}'),
            Text('• ${loc.tr('expense')}: ${importData.expenses.length}'),
            if (targetYear != null && targetMonth != null) ...[const SizedBox(height: 12), Text('${loc.tr('targetMonth')}: $targetYear. $targetMonth')],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(loc.tr('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(loc.tr('confirm'))),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (context.mounted) showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(content: Row(children: [const CircularProgressIndicator(), const SizedBox(width: 16), Text(loc.tr('importing'))])));

    try {
      final budgetData = importData.budgets.map((b) => {'name': b.name, 'amount': b.amount}).toList();
      final subBudgetData = importData.subBudgets.map((s) => {'budgetName': s.budgetName, 'name': s.name, 'amount': s.amount}).toList();
      final expenseData = importData.expenses.map((e) => {'date': e.date, 'budgetName': e.budgetName, 'subBudgetName': e.subBudgetName, 'memo': e.memo, 'amount': e.amount}).toList();
      final count = await budgetProvider.importData(budgetData: budgetData, subBudgetData: subBudgetData, expenseData: expenseData, targetYear: targetYear, targetMonth: targetMonth);
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${loc.tr('importSuccess')} ($count ${loc.tr('items')})'), backgroundColor: Colors.green));
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${loc.tr('importFailed')}: $e'), backgroundColor: Colors.red));
    }
  }

  void _showHelpDialog(BuildContext context, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.tr('help')),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(loc.tr('helpBudgetTab'), style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(loc.tr('helpBudgetDesc')), const SizedBox(height: 12),
            Text(loc.tr('helpSubBudget'), style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(loc.tr('helpSubBudgetDesc')), const SizedBox(height: 12),
            Text(loc.tr('helpStatsTab'), style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(loc.tr('helpStatsDesc')), const SizedBox(height: 12),
            Text(loc.tr('helpTip'), style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(loc.tr('helpTipDesc')),
          ]),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(loc.tr('confirm')))],
      ),
    );
  }
}

// 설정 행 데이터 클래스
class _SettingRowData {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? leading;
  final Widget? trailing;

  _SettingRowData({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.leading,
    this.trailing,
  });
}
