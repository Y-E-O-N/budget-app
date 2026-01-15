#!/usr/bin/env python3
# -*- coding: utf-8 -*-

content = r'''import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('설정')),
          body: ListView(
            children: [
              // 기본 설정 섹션
              _buildSectionHeader(context, '기본 설정'),
              _buildCurrencyTile(context, settings),
              _buildStartDayTile(context, settings),
              _buildMonthStartDayTile(context, settings),
              _buildLanguageTile(context, settings),

              // 알림 설정 섹션
              _buildSectionHeader(context, '알림 설정'),
              _buildDailyReminderTile(context, settings),
              _buildBudgetAlertTile(context, settings),

              // 화면/테마 섹션
              _buildSectionHeader(context, '화면/테마'),
              _buildThemeModeTile(context, settings),
              _buildFontSizeTile(context, settings),
              _buildColorThemeTile(context, settings),

              // 기타 섹션
              _buildSectionHeader(context, '기타'),
              _buildAboutTile(context),
              _buildHelpTile(context),

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

  // 통화 설정
  Widget _buildCurrencyTile(BuildContext context, SettingsProvider settings) {
    final currencies = [
      {'symbol': '₩', 'name': '원 (KRW)'},
      {'symbol': '\$', 'name': '달러 (USD)'},
      {'symbol': '¥', 'name': '엔 (JPY)'},
      {'symbol': '€', 'name': '유로 (EUR)'},
      {'symbol': '£', 'name': '파운드 (GBP)'},
    ];
    return ListTile(
      leading: const Icon(Icons.attach_money),
      title: const Text('통화 단위'),
      subtitle: Text(currencies.firstWhere((c) => c['symbol'] == settings.currency, orElse: () => currencies[0])['name']!),
      onTap: () => _showCurrencyDialog(context, settings, currencies),
    );
  }

  void _showCurrencyDialog(BuildContext context, SettingsProvider settings, List<Map<String, String>> currencies) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('통화 단위 선택'),
        children: currencies.map((c) => RadioListTile<String>(
          title: Text(c['name']!),
          value: c['symbol']!,
          groupValue: settings.currency,
          onChanged: (value) { if (value != null) { settings.setCurrency(value); Navigator.pop(context); } },
        )).toList(),
      ),
    );
  }

  // 시작 요일 설정
  Widget _buildStartDayTile(BuildContext context, SettingsProvider settings) {
    final days = {'monday': '월요일', 'sunday': '일요일'};
    return ListTile(
      leading: const Icon(Icons.calendar_view_week),
      title: const Text('시작 요일'),
      subtitle: Text(days[settings.startDayOfWeek] ?? '월요일'),
      onTap: () => _showStartDayDialog(context, settings, days),
    );
  }

  void _showStartDayDialog(BuildContext context, SettingsProvider settings, Map<String, String> days) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('시작 요일 선택'),
        children: days.entries.map((e) => RadioListTile<String>(
          title: Text(e.value),
          value: e.key,
          groupValue: settings.startDayOfWeek,
          onChanged: (value) { if (value != null) { settings.setStartDayOfWeek(value); Navigator.pop(context); } },
        )).toList(),
      ),
    );
  }

  // 월 시작일 설정
  Widget _buildMonthStartDayTile(BuildContext context, SettingsProvider settings) {
    return ListTile(
      leading: const Icon(Icons.calendar_today),
      title: const Text('월 시작일'),
      subtitle: Text('${settings.monthStartDay}일'),
      onTap: () => _showMonthStartDayDialog(context, settings),
    );
  }

  void _showMonthStartDayDialog(BuildContext context, SettingsProvider settings) {
    int selectedDay = settings.monthStartDay;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('월 시작일 선택'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('급여일이나 원하는 날짜를 선택하세요'),
              const SizedBox(height: 16),
              DropdownButton<int>(
                value: selectedDay,
                isExpanded: true,
                items: List.generate(28, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}일'))),
                onChanged: (value) { if (value != null) setState(() => selectedDay = value); },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            FilledButton(onPressed: () { settings.setMonthStartDay(selectedDay); Navigator.pop(context); }, child: const Text('확인')),
          ],
        ),
      ),
    );
  }

  // 언어 설정
  Widget _buildLanguageTile(BuildContext context, SettingsProvider settings) {
    final languages = {'ko': '한국어', 'en': 'English', 'ja': '日本語'};
    return ListTile(
      leading: const Icon(Icons.language),
      title: const Text('언어'),
      subtitle: Text(languages[settings.language] ?? '한국어'),
      onTap: () => _showLanguageDialog(context, settings, languages),
    );
  }

  void _showLanguageDialog(BuildContext context, SettingsProvider settings, Map<String, String> languages) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('언어 선택'),
        children: languages.entries.map((e) => RadioListTile<String>(
          title: Text(e.value),
          value: e.key,
          groupValue: settings.language,
          onChanged: (value) { if (value != null) { settings.setLanguage(value); Navigator.pop(context); } },
        )).toList(),
      ),
    );
  }

  // 일일 알림 설정
  Widget _buildDailyReminderTile(BuildContext context, SettingsProvider settings) {
    final timeStr = '${settings.dailyReminderHour.toString().padLeft(2, '0')}:${settings.dailyReminderMinute.toString().padLeft(2, '0')}';
    return SwitchListTile(
      secondary: const Icon(Icons.notifications),
      title: const Text('지출 입력 알림'),
      subtitle: Text(settings.dailyReminderEnabled ? '매일 $timeStr에 알림' : '꺼짐'),
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

  // 예산 알림 설정
  Widget _buildBudgetAlertTile(BuildContext context, SettingsProvider settings) {
    return SwitchListTile(
      secondary: const Icon(Icons.warning_amber),
      title: const Text('예산 초과 알림'),
      subtitle: Text(settings.budgetAlertEnabled ? '${settings.budgetAlertThreshold}% 사용 시 알림' : '꺼짐'),
      value: settings.budgetAlertEnabled,
      onChanged: (value) async {
        if (value) {
          final granted = await settings.requestNotificationPermission();
          if (!granted) return;
          if (context.mounted) _showBudgetAlertThresholdDialog(context, settings);
        } else {
          settings.setBudgetAlert(false);
        }
      },
    );
  }

  void _showBudgetAlertThresholdDialog(BuildContext context, SettingsProvider settings) {
    int threshold = settings.budgetAlertThreshold;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('예산 알림 기준'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$threshold% 사용 시 알림', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Slider(
                value: threshold.toDouble(),
                min: 50, max: 100, divisions: 10,
                label: '$threshold%',
                onChanged: (value) => setState(() => threshold = value.round()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            FilledButton(onPressed: () { settings.setBudgetAlert(true, threshold: threshold); Navigator.pop(context); }, child: const Text('확인')),
          ],
        ),
      ),
    );
  }

  // 테마 모드 설정
  Widget _buildThemeModeTile(BuildContext context, SettingsProvider settings) {
    final modes = {'system': '시스템 설정', 'light': '라이트 모드', 'dark': '다크 모드'};
    return ListTile(
      leading: const Icon(Icons.dark_mode),
      title: const Text('다크 모드'),
      subtitle: Text(modes[settings.themeModeSetting] ?? '시스템 설정'),
      onTap: () => _showThemeModeDialog(context, settings, modes),
    );
  }

  void _showThemeModeDialog(BuildContext context, SettingsProvider settings, Map<String, String> modes) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('테마 모드 선택'),
        children: modes.entries.map((e) => RadioListTile<String>(
          title: Text(e.value),
          value: e.key,
          groupValue: settings.themeModeSetting,
          onChanged: (value) { if (value != null) { settings.setThemeMode(value); Navigator.pop(context); } },
        )).toList(),
      ),
    );
  }

  // 글꼴 크기 설정
  Widget _buildFontSizeTile(BuildContext context, SettingsProvider settings) {
    final sizes = {0.85: '작게', 1.0: '보통', 1.15: '크게', 1.3: '매우 크게'};
    return ListTile(
      leading: const Icon(Icons.format_size),
      title: const Text('글꼴 크기'),
      subtitle: Text(sizes[settings.fontSizeScale] ?? '보통'),
      onTap: () => _showFontSizeDialog(context, settings, sizes),
    );
  }

  void _showFontSizeDialog(BuildContext context, SettingsProvider settings, Map<double, String> sizes) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('글꼴 크기 선택'),
        children: sizes.entries.map((e) => RadioListTile<double>(
          title: Text(e.value),
          value: e.key,
          groupValue: settings.fontSizeScale,
          onChanged: (value) { if (value != null) { settings.setFontSizeScale(value); Navigator.pop(context); } },
        )).toList(),
      ),
    );
  }

  // 색상 테마 설정
  Widget _buildColorThemeTile(BuildContext context, SettingsProvider settings) {
    final colors = [
      {'color': 0xFF6366F1, 'name': '인디고'},
      {'color': 0xFF22C55E, 'name': '그린'},
      {'color': 0xFF3B82F6, 'name': '블루'},
      {'color': 0xFFEF4444, 'name': '레드'},
      {'color': 0xFFF59E0B, 'name': '오렌지'},
      {'color': 0xFF8B5CF6, 'name': '퍼플'},
      {'color': 0xFFEC4899, 'name': '핑크'},
      {'color': 0xFF14B8A6, 'name': '틸'},
    ];
    final currentColor = colors.firstWhere((c) => c['color'] == settings.colorTheme, orElse: () => colors[0]);
    return ListTile(
      leading: Container(
        width: 24, height: 24,
        decoration: BoxDecoration(color: Color(settings.colorTheme), borderRadius: BorderRadius.circular(4)),
      ),
      title: const Text('색상 테마'),
      subtitle: Text(currentColor['name'] as String),
      onTap: () => _showColorThemeDialog(context, settings, colors),
    );
  }

  void _showColorThemeDialog(BuildContext context, SettingsProvider settings, List<Map<String, dynamic>> colors) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('색상 테마 선택'),
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

  // 앱 정보
  Widget _buildAboutTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('앱 정보'),
      subtitle: const Text('버전 1.0.0'),
      onTap: () => showAboutDialog(
        context: context,
        applicationName: '가계부',
        applicationVersion: '1.0.0',
        applicationLegalese: '© 2025',
        children: [
          const SizedBox(height: 16),
          const Text('간단하고 직관적인 가계부 앱입니다.'),
        ],
      ),
    );
  }

  // 도움말
  Widget _buildHelpTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.help_outline),
      title: const Text('도움말'),
      onTap: () => _showHelpDialog(context),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('도움말'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('예산 탭', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• + 버튼으로 예산 추가\n• 예산 터치로 상세 화면 이동\n• 길게 눌러 수정/삭제\n'),
              Text('세부예산', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• 예산 내 세부 항목 관리\n• 각 세부예산별 지출 추적\n'),
              Text('통계 탭', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• 예산별 사용 현황 파이 차트\n• 차트 터치로 상세 정보 확인\n'),
              Text('팁', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• "매달 적용" 체크 시 다음 달에 자동 복사'),
            ],
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
      ),
    );
  }
}
'''

with open(r'C:\SY\app\budget_app\lib\screens\settings_tab.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('settings_tab.dart updated')
