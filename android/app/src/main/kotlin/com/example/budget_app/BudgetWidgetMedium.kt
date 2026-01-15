package com.example.budget_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import java.text.NumberFormat
import java.util.Locale

/**
 * Medium Widget Provider - 지출/잔액 표시
 * 세 줄: 예산명+전체금액 / 지출 / 잔액
 */
class BudgetWidgetMedium : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_medium)

            // SharedPreferences에서 데이터 가져오기
            val prefs = context.getSharedPreferences("home_widget", Context.MODE_PRIVATE)

            val budgetName = prefs.getString("medium_budgetName", "예산") ?: "예산"
            val totalBudget = prefs.getLong("medium_totalBudget", 0L)
            val spent = prefs.getLong("medium_spent", 0L)
            val remaining = prefs.getLong("medium_remaining", 0L)
            val isWarning = prefs.getBoolean("medium_isWarning", false)

            // 금액 포맷팅
            val formatter = NumberFormat.getCurrencyInstance(Locale.KOREA)

            // 뷰 업데이트
            views.setTextViewText(R.id.budget_name, budgetName)
            views.setTextViewText(R.id.total_budget, formatter.format(totalBudget))
            views.setTextViewText(R.id.spent_amount, formatter.format(spent))
            views.setTextViewText(R.id.remaining_amount, formatter.format(remaining))

            // 경고 색상 (20% 이하)
            val textColor = if (isWarning) 0xFFE53935.toInt() else 0xFF000000.toInt()
            views.setTextColor(R.id.remaining_amount, textColor)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
