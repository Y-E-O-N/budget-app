package com.example.budget_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import java.text.NumberFormat
import java.util.Locale

/**
 * Large Widget Provider - 카테고리별 상세
 * 최대 5개 카테고리 표시
 */
class BudgetWidgetLarge : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_large)

            // SharedPreferences에서 데이터 가져오기
            val prefs = context.getSharedPreferences("home_widget", Context.MODE_PRIVATE)
            val categoryCount = prefs.getInt("large_categoryCount", 0)

            val formatter = NumberFormat.getCurrencyInstance(Locale.KOREA)

            // 카테고리 ID 배열
            val categoryIds = arrayOf(
                Triple(R.id.category_1, "large_cat0", arrayOf(R.id.category_name, R.id.category_spent, R.id.category_budget, R.id.category_remaining)),
                Triple(R.id.category_2, "large_cat1", arrayOf(R.id.category_name, R.id.category_spent, R.id.category_budget, R.id.category_remaining)),
                Triple(R.id.category_3, "large_cat2", arrayOf(R.id.category_name, R.id.category_spent, R.id.category_budget, R.id.category_remaining)),
                Triple(R.id.category_4, "large_cat3", arrayOf(R.id.category_name, R.id.category_spent, R.id.category_budget, R.id.category_remaining)),
                Triple(R.id.category_5, "large_cat4", arrayOf(R.id.category_name, R.id.category_spent, R.id.category_budget, R.id.category_remaining))
            )

            for (i in 0 until 5) {
                val (containerId, prefix, _) = categoryIds[i]

                if (i < categoryCount) {
                    val name = prefs.getString("${prefix}_name", "") ?: ""
                    val budget = prefs.getLong("${prefix}_budget", 0L)
                    val spent = prefs.getLong("${prefix}_spent", 0L)
                    val remaining = prefs.getLong("${prefix}_remaining", 0L)
                    val isWarning = prefs.getBoolean("${prefix}_isWarning", false)

                    // 카테고리 표시
                    views.setViewVisibility(containerId, View.VISIBLE)

                    // RemoteViews는 include 내부에 직접 접근 불가하므로
                    // 별도 처리 필요 - 여기서는 기본값 사용
                } else {
                    // 빈 카테고리 숨기기
                    views.setViewVisibility(containerId, View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
