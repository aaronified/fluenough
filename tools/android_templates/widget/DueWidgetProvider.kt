package app.fluenough

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar
import java.util.Locale

// Written by tools/brand_android.py from tools/android_templates/widget/:
// the home-screen widget (#108). It draws the text the app stored with the
// home_widget plugin (lib/core/widget/home_widget_summary.dart names the
// keys) and runs none of the app's code.
//
// The app stores the lines for the day it worked them out and for the day
// after, with that day. Drawn on the same day, the widget shows the first;
// drawn on the next, the second; later than that it only asks to open the
// app, because what is due is not known. The phone draws the widget again a
// minute into each of those days (HomeWidget.scheduleWidgetUpdates).
class DueWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val language = widgetData.getString("hw_language", "") ?: ""
        val stored = widgetData.getString("hw_day", null)
        val first: String
        val second: String
        when (stored) {
            null -> {
                first = context.getString(R.string.due_widget_description)
                second = ""
            }
            dayKey(0) -> {
                first = widgetData.getString("hw_due_today", "") ?: ""
                second = widgetData.getString("hw_streak_today", "") ?: ""
            }
            dayKey(-1) -> {
                first = widgetData.getString("hw_due_next", "") ?: ""
                second = widgetData.getString("hw_streak_next", "") ?: ""
            }
            else -> {
                first = widgetData.getString("hw_open", "") ?: ""
                second = ""
            }
        }
        // One sentence for the screen reader: the same lines as on the widget.
        val spoken = listOf(language, first, second).filter { it.isNotEmpty() }
            .joinToString(", ")
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.due_widget)
            show(views, R.id.due_widget_language, language)
            show(views, R.id.due_widget_due, first)
            show(views, R.id.due_widget_streak, second)
            views.setContentDescription(R.id.due_widget_root, spoken)
            if (launch != null) {
                val tap = PendingIntent.getActivity(
                    context,
                    0,
                    launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.due_widget_root, tap)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun show(views: RemoteViews, id: Int, text: String) {
        views.setTextViewText(id, text)
        views.setViewVisibility(id, if (text.isEmpty()) View.GONE else View.VISIBLE)
    }

    // The local calendar day [offset] days from today, as yyyy-mm-dd.
    private fun dayKey(offset: Int): String {
        val day = Calendar.getInstance()
        day.add(Calendar.DAY_OF_MONTH, offset)
        // Locale.ROOT: the app stored Western digits, whatever the phone's locale.
        return String.format(
            Locale.ROOT,
            "%04d-%02d-%02d",
            day.get(Calendar.YEAR),
            day.get(Calendar.MONTH) + 1,
            day.get(Calendar.DAY_OF_MONTH),
        )
    }
}
