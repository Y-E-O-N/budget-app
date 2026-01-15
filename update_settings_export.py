#!/usr/bin/env python3
# -*- coding: utf-8 -*-

content = r'''import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_localizations.dart';
import '../providers/settings_provider.dart';
import '../providers/budget_provider.dart';
import '../services/export_service.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final loc = context.loc;
        return Scaffold(
          appBar: AppBar(title: Text(loc.tr('settings'))),
          body: ListView(
            children: [
              _buildSectionHeader(context, loc.tr('basicSettings')),
              _buildCurrencyTile(context, settings, loc),
              _buildStartDayTile(context, settings, loc),
              _buildMonthStartDayTile(context, settings, loc),
              _buildLanguageTile(context, settings, loc),

              _buildSectionHeader(context, loc.tr('notificationSettings')),
              _buildDailyReminderTile(context, settings, loc),
              _buildBudgetAlertTile(context, settings, loc),

              _buildSectionHeader(context, loc.tr('displaySettings')),
              _buildThemeModeTile(context, settings, loc),
              _buildFontSizeTile(context, settings, loc),
              _buildColorThemeTile(context, settings, loc),

              _buildSectionHeader(context, loc.tr('dataManagement')),
              _buildExportTile(context, settings, loc),

              _buildSectionHeader(context, loc.tr('others')),
              _buildAboutTile(context, loc),
              _buildHelpTile(context, loc),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget _buildCurrencyTile(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    final currencies = [
      {'symbol': '₩', 'name': '원 (KRW)'},
      {'symbol': '\$', 'name': 'Dollar (USD)'},
      {'symbol': '¥', 'name': '円 (JPY)'},
      {'symbol': '€', 'name': 'Euro (EUR)'},
      {'symbol': '£', 'name': 'Pound (GBP)'},
    ];
    return ListTile(
      leading: const Icon(Icons.attach_money),
      title: Text(loc.tr('currency')),
      subtitle: Text(currencies.firstWhere((c) => c['symbol'] == settings.currency, orElse: () => currencies[0])['name']!),
      onTap: () => _showCurrencyDialog(context, settings, currencies, loc),
    );
  }

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

  Widget _buildStartDayTile(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    final days = {
      'monday': loc.tr('monday'), 'tuesday': loc.tr('tuesday'), 'wednesday': loc.tr('wednesday'),
      'thursday': loc.tr('thursday'), 'friday': loc.tr('friday'), 'saturday': loc.tr('saturday'), 'sunday': loc.tr('sunday')
    };
    return ListTile(
      leading: const Icon(Icons.calendar_view_week),
      title: Text(loc.tr('startDayOfWeek')),
      subtitle: Text(days[settings.startDayOfWeek] ?? loc.tr('monday')),
      onTap: () => _showStartDayDialog(context, settings, days, loc),
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

  Widget _buildMonthStartDayTile(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    return ListTile(
      leading: const Icon(Icons.calendar_today),
      title: Text(loc.tr('monthStartDay')),
      subtitle: Text('${settings.monthStartDay}'),
      onTap: () => _showMonthStartDayDialog(context, settings, loc),
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
              Text(loc.tr('monthStartDayDesc')),
              const SizedBox(height: 16),
              DropdownButton<int>(
                value: selectedDay,
                isExpanded: true,
                items: List.generate(28, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                onChanged: (value) { if (value != null) setState(() => selectedDay = value); },
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

  Widget _buildLanguageTile(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    final languages = {'ko': '한국어', 'en': 'English', 'ja': '日本語'};
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(loc.tr('language')),
      subtitle: Text(languages[settings.language] ?? '한국어'),
      onTap: () => _showLanguageDialog(context, settings, languages, loc),
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

  Widget _buildDailyReminderTile(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    final timeStr = '${settings.dailyReminderHour.toString().padLeft(2, '0')}:${settings.dailyReminderMinute.toString().padLeft(2, '0')}';
    return SwitchListTile(
      secondary: const Icon(Icons.notifications),
      title: Text(loc.tr('dailyReminder')),
      subtitle: Text(settings.dailyReminderEnabled ? timeStr : loc.tr('off')),
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
    );
  }

  Future<void> _showTimePickerForReminder(BuildContext context, SettingsProvider settings, bool enabled) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.dailyReminderHour, minute: settings.dailyReminderMinute),
    );
    if (time != null) {
      await settings.setDailyReminder(enabled, hour: time.hour, minute: time.minute);
    }
  }

  Widget _buildBudgetAlertTile(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    return SwitchListTile(
      secondary: const Icon(Icons.warning_amber),
      title: Text(loc.tr('budgetAlert')),
      subtitle: Text(settings.budgetAlertEnabled ? '${settings.budgetAlertThreshold}%' : loc.tr('off')),
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
    );
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
              Text('$threshold%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Slider(
                value: threshold.toDouble(),
                min: 50, max: 100, divisions: 10,
                label: '$threshold%',
                onChanged: (value) => setState(() => threshold = value.round()),
              ),
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

  Widget _buildThemeModeTile(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    final modes = {'system': loc.tr('systemSetting'), 'light': loc.tr('lightMode'), 'dark': loc.tr('darkModeOption')};
    return ListTile(
      leading: const Icon(Icons.dark_mode),
      title: Text(loc.tr('darkMode')),
      subtitle: Text(modes[settings.themeModeSetting] ?? loc.tr('systemSetting')),
      onTap: () => _showThemeModeDialog(context, settings, modes, loc),
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

  Widget _buildFontSizeTile(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    final sizes = {0.85: loc.tr('fontSmall'), 1.0: loc.tr('fontNormal'), 1.15: loc.tr('fontLarge'), 1.3: loc.tr('fontExtraLarge')};
    return ListTile(
      leading: const Icon(Icons.format_size),
      title: Text(loc.tr('fontSize')),
      subtitle: Text(sizes[settings.fontSizeScale] ?? loc.tr('fontNormal')),
      onTap: () => _showFontSizeDialog(context, settings, sizes, loc),
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

  Widget _buildColorThemeTile(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
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
    final currentColor = colors.firstWhere((c) => c['color'] == settings.colorTheme, orElse: () => colors[0]);
    return ListTile(
      leading: Container(width: 24, height: 24, decoration: BoxDecoration(color: Color(settings.colorTheme), borderRadius: BorderRadius.circular(4))),
      title: Text(loc.tr('colorTheme')),
      subtitle: Text(currentColor['name'] as String),
      onTap: () => _showColorThemeDialog(context, settings, colors, loc),
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

  Widget _buildExportTile(BuildContext context, SettingsProvider settings, AppLocalizations loc) {
    return ListTile(
      leading: const Icon(Icons.file_download),
      title: Text(loc.tr('exportExcel')),
      subtitle: Text(loc.tr('exportExcelDesc')),
      onTap: () => _exportToExcel(context, settings, loc),
    );
  }

  Future<void> _exportToExcel(BuildContext context, SettingsProvider settings, AppLocalizations loc) async {
    final budgetProvider = context.read<BudgetProvider>();

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Text(loc.tr('exporting')),
        ]),
      ),
    );

    try {
      final exportService = ExportService(
        language: settings.language,
        currency: settings.currency,
      );

      final success = await exportService.exportToExcel(
        budgets: budgetProvider.currentBudgets,
        subBudgets: budgetProvider.currentBudgets.expand((b) => budgetProvider.getSubBudgets(b.id)).toList(),
        expenses: budgetProvider.currentBudgets.expand((b) => budgetProvider.getExpenses(b.id)).toList(),
        year: budgetProvider.currentYear,
        month: budgetProvider.currentMonth,
        getTotalExpense: budgetProvider.getTotalExpense,
        getSubBudgetExpense: budgetProvider.getSubBudgetExpense,
      );

      if (context.mounted) Navigator.pop(context); // 로딩 닫기

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? loc.tr('exportSuccess') : loc.tr('exportFailed')),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.tr('exportFailed')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildAboutTile(BuildContext context, AppLocalizations loc) {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: Text(loc.tr('appInfo')),
      subtitle: Text('${loc.tr('version')} 1.0.0'),
      onTap: () => showAboutDialog(
        context: context,
        applicationName: loc.tr('appTitle'),
        applicationVersion: '1.0.0',
        applicationLegalese: '© 2025',
        children: [const SizedBox(height: 16), Text(loc.tr('appDesc'))],
      ),
    );
  }

  Widget _buildHelpTile(BuildContext context, AppLocalizations loc) {
    return ListTile(
      leading: const Icon(Icons.help_outline),
      title: Text(loc.tr('help')),
      onTap: () => _showHelpDialog(context, loc),
    );
  }

  void _showHelpDialog(BuildContext context, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.tr('help')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.tr('helpBudgetTab'), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(loc.tr('helpBudgetDesc')),
              const SizedBox(height: 12),
              Text(loc.tr('helpSubBudget'), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(loc.tr('helpSubBudgetDesc')),
              const SizedBox(height: 12),
              Text(loc.tr('helpStatsTab'), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(loc.tr('helpStatsDesc')),
              const SizedBox(height: 12),
              Text(loc.tr('helpTip'), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(loc.tr('helpTipDesc')),
            ],
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(loc.tr('confirm')))],
      ),
    );
  }
}
'''

with open(r'C:\SY\app\budget_app\lib\screens\settings_tab.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('settings_tab.dart updated')
