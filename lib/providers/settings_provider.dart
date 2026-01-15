// =============================================================================
// settings_provider.dart - 앱 설정 상태 관리
// =============================================================================
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class SettingsProvider extends ChangeNotifier {
  late Box _settingsBox;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // 기본값
  static const String defaultCurrency = '₩';
  static const String defaultStartDayOfWeek = 'monday';
  static const int defaultMonthStartDay = 1;
  static const String defaultLanguage = 'ko';
  static const String defaultThemeMode = 'system';
  static const double defaultFontSize = 1.0;
  static const int defaultColorTheme = 0xFF6366F1;

  // Getters
  String get currency => _settingsBox.get('currency', defaultValue: defaultCurrency);
  String get startDayOfWeek => _settingsBox.get('startDayOfWeek', defaultValue: defaultStartDayOfWeek);
  int get monthStartDay => _settingsBox.get('monthStartDay', defaultValue: defaultMonthStartDay);
  String get language => _settingsBox.get('language', defaultValue: defaultLanguage);
  String get themeModeSetting => _settingsBox.get('themeMode', defaultValue: defaultThemeMode);
  double get fontSizeScale => _settingsBox.get('fontSize', defaultValue: defaultFontSize);
  int get colorTheme => _settingsBox.get('colorTheme', defaultValue: defaultColorTheme);

  // Gemini API 키
  String get geminiApiKey => _settingsBox.get('geminiApiKey', defaultValue: '');

  // 알림 설정
  bool get dailyReminderEnabled => _settingsBox.get('dailyReminderEnabled', defaultValue: false);
  int get dailyReminderHour => _settingsBox.get('dailyReminderHour', defaultValue: 21);
  int get dailyReminderMinute => _settingsBox.get('dailyReminderMinute', defaultValue: 0);
  bool get budgetAlertEnabled => _settingsBox.get('budgetAlertEnabled', defaultValue: true);
  int get budgetAlertThreshold => _settingsBox.get('budgetAlertThreshold', defaultValue: 80);

  ThemeMode get themeMode {
    switch (themeModeSetting) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  // 초기화
  Future<void> init() async {
    _settingsBox = await Hive.openBox('settings');
    tz.initializeTimeZones();
    await _initNotifications();
    notifyListeners();
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notifications.initialize(settings);
  }

  // 통화 설정
  Future<void> setCurrency(String value) async {
    await _settingsBox.put('currency', value);
    notifyListeners();
  }

  // 시작 요일 설정
  Future<void> setStartDayOfWeek(String value) async {
    await _settingsBox.put('startDayOfWeek', value);
    notifyListeners();
  }

  // 월 시작일 설정
  Future<void> setMonthStartDay(int value) async {
    await _settingsBox.put('monthStartDay', value);
    notifyListeners();
  }

  // 언어 설정
  Future<void> setLanguage(String value) async {
    await _settingsBox.put('language', value);
    notifyListeners();
  }

  // 테마 모드 설정
  Future<void> setThemeMode(String value) async {
    await _settingsBox.put('themeMode', value);
    notifyListeners();
  }

  // 글꼴 크기 설정
  Future<void> setFontSizeScale(double value) async {
    await _settingsBox.put('fontSize', value);
    notifyListeners();
  }

  // 색상 테마 설정
  Future<void> setColorTheme(int value) async {
    await _settingsBox.put('colorTheme', value);
    notifyListeners();
  }

  // Gemini API 키 설정
  Future<void> setGeminiApiKey(String value) async {
    await _settingsBox.put('geminiApiKey', value);
    notifyListeners();
  }

  // 일일 알림 설정
  Future<void> setDailyReminder(bool enabled, {int? hour, int? minute}) async {
    await _settingsBox.put('dailyReminderEnabled', enabled);
    if (hour != null) await _settingsBox.put('dailyReminderHour', hour);
    if (minute != null) await _settingsBox.put('dailyReminderMinute', minute);

    if (enabled) {
      await _scheduleDailyReminder();
    } else {
      await _notifications.cancel(0);
    }
    notifyListeners();
  }

  Future<void> _scheduleDailyReminder() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local, now.year, now.month, now.day,
      dailyReminderHour, dailyReminderMinute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      0,
      '가계부',
      '오늘 지출을 기록해주세요!',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder', '일일 알림',
          channelDescription: '매일 지출 입력 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // 예산 초과 알림 설정
  Future<void> setBudgetAlert(bool enabled, {int? threshold}) async {
    await _settingsBox.put('budgetAlertEnabled', enabled);
    if (threshold != null) await _settingsBox.put('budgetAlertThreshold', threshold);
    notifyListeners();
  }

  // 예산 초과 알림 표시
  Future<void> showBudgetAlert(String budgetName, int percentage) async {
    if (!budgetAlertEnabled) return;
    if (percentage < budgetAlertThreshold) return;

    await _notifications.show(
      1,
      '예산 알림',
      '$budgetName 예산의 $percentage%를 사용했습니다.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_alert', '예산 알림',
          channelDescription: '예산 초과 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // 알림 권한 요청
  Future<bool> requestNotificationPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }
}
