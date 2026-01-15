package com.example.budget_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.NumberFormat
import java.util.Locale

/**
 * Small Widget Provider - 잔액 표시
 * 두 줄: 예산명+잔여기간 / 잔액
 */
class BudgetWidgetSmall : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_small)

            // SharedPreferences에서 데이터 가져오기
            val prefs = context.getSharedPreferences("home_widget", Context.MODE_PRIVATE)

            val budgetName = prefs.getString("small_budgetName", "예산") ?: "예산"
            val remaining = prefs.getLong("small_remaining", 0L)
            val remainingDays = prefs.getInt("small_remainingDays", 0)
            val isWarning = prefs.getBoolean("small_isWarning", false)

            // 금액 포맷팅
            val formatter = NumberFormat.getCurrencyInstance(Locale.KOREA)
            val formattedRemaining = formatter.format(remaining)

            // 뷰 업데이트
            views.setTextViewText(R.id.budget_name, budgetName)
            views.setTextViewText(R.id.remaining_days, "D-$remainingDays")
            views.setTextViewText(R.id.remaining_amount, formattedRemaining)

            // 경고 색상 (20% 이하)
            val textColor = if (isWarning) 0xFFE53935.toInt() else 0xFF000000.toInt()
            views.setTextColor(R.id.remaining_amount, textColor)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
