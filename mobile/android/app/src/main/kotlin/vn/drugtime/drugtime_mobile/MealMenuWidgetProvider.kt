package vn.drugtime.drugtime_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/**
 * Widget "Thực đơn hôm nay" (task adhoc-20261118-meal-suggestion-redesign, mục H).
 *
 * Dữ liệu do app ghi qua `home_widget` (khóa trong `MealWidgetKeys` phía Dart): chỉ tên món, kcal,
 * đường dẫn ảnh nhỏ; không có thuốc, bệnh, dị ứng. Widget không chạy hoạt họa.
 */
class MealMenuWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) render(context, appWidgetManager, id, widgetData)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        render(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context))
    }

    private fun render(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        data: SharedPreferences,
    ) {
        val minWidth = manager.getAppWidgetOptions(id)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val small = minWidth in 1 until 200
        val views = if (small) smallViews(context, data) else bigViews(context, data)
        views.setOnClickPendingIntent(R.id.meal_widget_root, launch(context, null))
        manager.updateAppWidget(id, views)
    }

    /** Trạng thái chung: `null` nghĩa là có dữ liệu hôm nay để hiện từng bữa. */
    private fun message(context: Context, data: SharedPreferences): String? {
        val state = data.getString("menu_state", null)
        if (state == "signed_out") return context.getString(R.string.meal_widget_signed_out)
        // Qua 00:00 giờ VN hoặc chưa từng có dữ liệu: món hôm qua không còn giá trị.
        if (state == null || data.getString("menu_day", "") != todayVn()) {
            return context.getString(R.string.meal_widget_open_today)
        }
        return null
    }

    private fun bigViews(context: Context, data: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.meal_menu_widget)
        views.setOnClickPendingIntent(R.id.meal_widget_button, launch(context, null))
        val text = message(context, data)
        views.setViewVisibility(R.id.meal_widget_message, if (text == null) View.GONE else View.VISIBLE)
        views.setViewVisibility(R.id.meal_widget_rows, if (text == null) View.VISIBLE else View.GONE)
        if (text != null) {
            views.setTextViewText(R.id.meal_widget_message, text)
            return views
        }
        val upcoming = upcomingMeal()
        for (meal in MEALS) {
            val name = data.getString("meal_${meal.key}_name", null)
            views.setTextViewText(meal.name, name ?: context.getString(R.string.meal_widget_not_chosen))
            views.setTextColor(meal.name, if (name == null) GREY else INK)
            views.setTextViewText(meal.kcal, data.getString("meal_${meal.key}_kcal", null) ?: "")
            views.setTextColor(meal.label, if (meal.key == upcoming) BRAND else GREY)
            views.setInt(
                meal.row,
                "setBackgroundResource",
                if (meal.key == upcoming) R.drawable.meal_widget_row_active else R.drawable.meal_widget_row,
            )
            val bitmap = data.getString("meal_${meal.key}_img", null)
                ?.takeIf { name != null && File(it).exists() }
                ?.let { BitmapFactory.decodeFile(it) }
            if (bitmap != null) {
                views.setImageViewBitmap(meal.thumb, bitmap)
            } else {
                views.setImageViewResource(meal.thumb, meal.dot)
            }
            views.setOnClickPendingIntent(meal.row, launch(context, meal.key))
        }
        return views
    }

    private fun smallViews(context: Context, data: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.meal_menu_widget_small)
        val text = message(context, data)
        val meal = MEALS.first { it.key == upcomingMeal() }
        views.setTextViewText(R.id.small_meal, context.getString(meal.mealLabel))
        val name = if (text == null) data.getString("meal_${meal.key}_name", null) else null
        views.setTextViewText(
            R.id.small_name,
            text ?: name ?: context.getString(R.string.meal_widget_not_chosen),
        )
        if (text == null) {
            views.setOnClickPendingIntent(R.id.meal_widget_root, launch(context, meal.key))
        }
        return views
    }

    /** Mở app tới màn gợi ý: `drugtime://meal?meal=toi` (một bữa) hoặc `drugtime://meal`. */
    private fun launch(context: Context, meal: String?) = HomeWidgetLaunchIntent.getActivity(
        context,
        MainActivity::class.java,
        Uri.parse(if (meal == null) "drugtime://meal" else "drugtime://meal?meal=$meal"),
    )

    private class Meal(
        val key: String,
        val row: Int,
        val label: Int,
        val thumb: Int,
        val name: Int,
        val kcal: Int,
        val dot: Int,
        val mealLabel: Int,
    )

    companion object {
        private const val INK = 0xFF1E2321.toInt()
        private const val GREY = 0xFF5E6663.toInt()
        private const val BRAND = 0xFF00594F.toInt()
        private val VN: TimeZone = TimeZone.getTimeZone("Asia/Ho_Chi_Minh")

        private val MEALS = listOf(
            Meal("sang", R.id.row_sang, R.id.label_sang, R.id.thumb_sang, R.id.name_sang,
                R.id.kcal_sang, R.drawable.meal_widget_dot_sang, R.string.meal_widget_meal_sang),
            Meal("trua", R.id.row_trua, R.id.label_trua, R.id.thumb_trua, R.id.name_trua,
                R.id.kcal_trua, R.drawable.meal_widget_dot_trua, R.string.meal_widget_meal_trua),
            Meal("toi", R.id.row_toi, R.id.label_toi, R.id.thumb_toi, R.id.name_toi,
                R.id.kcal_toi, R.drawable.meal_widget_dot_toi, R.string.meal_widget_meal_toi),
        )

        /** Ngày theo giờ Việt Nam, cùng định dạng `vietnamDay` phía Dart. */
        fun todayVn(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            .apply { timeZone = VN }
            .format(Calendar.getInstance(VN).time)

        /** Bữa sắp tới theo giờ VN, khớp `MealType.forVietnamTime`: <10h sáng, <16h trưa. */
        fun upcomingMeal(): String {
            val hour = Calendar.getInstance(VN).get(Calendar.HOUR_OF_DAY)
            return when {
                hour < 10 -> "sang"
                hour < 16 -> "trua"
                else -> "toi"
            }
        }
    }
}
