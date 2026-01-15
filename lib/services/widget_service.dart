// =============================================================================
// widget_service.dart - 홈 화면 위젯 데이터 서비스
// =============================================================================
import 'package:home_widget/home_widget.dart';
import '../providers/budget_provider.dart';

/// 위젯 타입
enum WidgetType {
  small,  // 잔액 표시
  medium, // 지출/잔액 표시
  large,  // 카테고리별 상세
}

/// 위젯에 표시할 데이터
class WidgetData {
  final String budgetName;
  final int totalBudget;
  final int spent;
  final int remaining;
  final int remainingDays;
  final double remainingPercent;
  final bool isWarning; // 20% 이하 경고

  const WidgetData({
    required this.budgetName,
    required this.totalBudget,
    required this.spent,
    required this.remaining,
    required this.remainingDays,
    required this.remainingPercent,
    required this.isWarning,
  });

  Map<String, dynamic> toJson() => {
    'budgetName': budgetName,
    'totalBudget': totalBudget,
    'spent': spent,
    'remaining': remaining,
    'remainingDays': remainingDays,
    'remainingPercent': remainingPercent,
    'isWarning': isWarning,
  };
}

/// 카테고리별 데이터 (Large 위젯용)
class CategoryData {
  final String name;
  final int budget;
  final int spent;
  final int remaining;
  final double percent;
  final bool isWarning;

  const CategoryData({
    required this.name,
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.percent,
    required this.isWarning,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'budget': budget,
    'spent': spent,
    'remaining': remaining,
    'percent': percent,
    'isWarning': isWarning,
  };
}

/// 홈 화면 위젯 서비스
class WidgetService {
  // Android 위젯 Provider 이름
  static const String androidWidgetProviderSmall = 'BudgetWidgetSmall';
  static const String androidWidgetProviderMedium = 'BudgetWidgetMedium';
  static const String androidWidgetProviderLarge = 'BudgetWidgetLarge';

  // iOS 위젯 그룹 ID
  static const String iOSAppGroupId = 'group.com.example.budgetapp.widget';

  /// 위젯 초기화
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(iOSAppGroupId);
  }

  /// 잔여 기간 계산 (현재 월 기준)
  static int _calculateRemainingDays() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    return lastDay - now.day;
  }

  /// Small 위젯 데이터 업데이트 (특정 예산/세부예산)
  static Future<void> updateSmallWidget({
    required String budgetId,
    String? subBudgetId,
    required BudgetProvider provider,
  }) async {
    final budget = provider.getBudgetById(budgetId);
    if (budget == null) return;

    String name;
    int totalAmount;
    int spent;

    if (subBudgetId != null) {
      // 세부예산 선택
      final subBudget = provider.getSubBudgetById(subBudgetId);
      if (subBudget == null) return;
      name = subBudget.name;
      totalAmount = subBudget.amount;
      spent = provider.getSubBudgetExpense(subBudgetId);
    } else {
      // 예산 전체
      name = budget.name;
      totalAmount = budget.amount;
      spent = provider.getTotalExpense(budgetId);
    }

    final remaining = totalAmount - spent;
    final remainingPercent = totalAmount > 0 ? (remaining / totalAmount) * 100 : 0.0;
    final isWarning = remainingPercent <= 20;
    final remainingDays = _calculateRemainingDays();

    // 데이터 저장
    await HomeWidget.saveWidgetData('small_budgetName', name);
    await HomeWidget.saveWidgetData('small_remaining', remaining);
    await HomeWidget.saveWidgetData('small_remainingDays', remainingDays);
    await HomeWidget.saveWidgetData('small_isWarning', isWarning);

    // 위젯 갱신
    await HomeWidget.updateWidget(
      androidName: androidWidgetProviderSmall,
      iOSName: 'BudgetWidgetSmall',
    );
  }

  /// Medium 위젯 데이터 업데이트
  static Future<void> updateMediumWidget({
    required String budgetId,
    required BudgetProvider provider,
  }) async {
    final budget = provider.getBudgetById(budgetId);
    if (budget == null) return;

    final spent = provider.getTotalExpense(budgetId);
    final remaining = budget.amount - spent;
    final remainingPercent = budget.amount > 0 ? (remaining / budget.amount) * 100 : 0.0;
    final isWarning = remainingPercent <= 20;

    // 데이터 저장
    await HomeWidget.saveWidgetData('medium_budgetName', budget.name);
    await HomeWidget.saveWidgetData('medium_totalBudget', budget.amount);
    await HomeWidget.saveWidgetData('medium_spent', spent);
    await HomeWidget.saveWidgetData('medium_remaining', remaining);
    await HomeWidget.saveWidgetData('medium_isWarning', isWarning);

    // 위젯 갱신
    await HomeWidget.updateWidget(
      androidName: androidWidgetProviderMedium,
      iOSName: 'BudgetWidgetMedium',
    );
  }

  /// Large 위젯 데이터 업데이트 (전체 카테고리)
  static Future<void> updateLargeWidget({
    required BudgetProvider provider,
  }) async {
    final budgets = provider.currentBudgets;
    final categories = <Map<String, dynamic>>[];

    for (int i = 0; i < budgets.length && i < 5; i++) {
      final budget = budgets[i];
      final spent = provider.getTotalExpense(budget.id);
      final remaining = budget.amount - spent;
      final percent = budget.amount > 0 ? (remaining / budget.amount) * 100 : 0.0;

      categories.add({
        'name': budget.name,
        'budget': budget.amount,
        'spent': spent,
        'remaining': remaining,
        'percent': percent,
        'isWarning': percent <= 20,
      });
    }

    // 카테고리 데이터 저장 (최대 5개)
    for (int i = 0; i < 5; i++) {
      if (i < categories.length) {
        final cat = categories[i];
        await HomeWidget.saveWidgetData('large_cat${i}_name', cat['name']);
        await HomeWidget.saveWidgetData('large_cat${i}_budget', cat['budget']);
        await HomeWidget.saveWidgetData('large_cat${i}_spent', cat['spent']);
        await HomeWidget.saveWidgetData('large_cat${i}_remaining', cat['remaining']);
        await HomeWidget.saveWidgetData('large_cat${i}_isWarning', cat['isWarning']);
      } else {
        // 빈 데이터
        await HomeWidget.saveWidgetData('large_cat${i}_name', '');
        await HomeWidget.saveWidgetData('large_cat${i}_budget', 0);
        await HomeWidget.saveWidgetData('large_cat${i}_spent', 0);
        await HomeWidget.saveWidgetData('large_cat${i}_remaining', 0);
        await HomeWidget.saveWidgetData('large_cat${i}_isWarning', false);
      }
    }

    await HomeWidget.saveWidgetData('large_categoryCount', categories.length);

    // 위젯 갱신
    await HomeWidget.updateWidget(
      androidName: androidWidgetProviderLarge,
      iOSName: 'BudgetWidgetLarge',
    );
  }

  /// 모든 위젯 업데이트
  static Future<void> updateAllWidgets({
    required BudgetProvider provider,
    String? smallBudgetId,
    String? smallSubBudgetId,
    String? mediumBudgetId,
  }) async {
    // Small 위젯
    if (smallBudgetId != null) {
      await updateSmallWidget(
        budgetId: smallBudgetId,
        subBudgetId: smallSubBudgetId,
        provider: provider,
      );
    }

    // Medium 위젯
    if (mediumBudgetId != null) {
      await updateMediumWidget(
        budgetId: mediumBudgetId,
        provider: provider,
      );
    }

    // Large 위젯
    await updateLargeWidget(provider: provider);
  }

  /// 위젯 클릭 이벤트 처리
  static Future<Uri?> getInitialUri() async {
    return await HomeWidget.initiallyLaunchedFromHomeWidget();
  }

  /// 위젯 클릭 스트림
  static Stream<Uri?> get widgetClicked => HomeWidget.widgetClicked;
}
