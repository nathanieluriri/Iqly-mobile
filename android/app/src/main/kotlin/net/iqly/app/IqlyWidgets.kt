package net.iqly.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

class ClosingSoonWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { manager.updateAppWidget(it, IqlyWidgets.closingSoon(context)) }
    }
}

class PollsWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { manager.updateAppWidget(it, IqlyWidgets.polls(context)) }
    }
}

// Draws the snapshot as published; all wording and counting happens in Dart.
object IqlyWidgets {
    private val rows = listOf(
        Row(R.id.row_1, R.id.row_1_thumb, R.id.row_1_title, R.id.row_1_meta),
        Row(R.id.row_2, R.id.row_2_thumb, R.id.row_2_title, R.id.row_2_meta),
    )

    private data class Row(val root: Int, val thumb: Int, val title: Int, val meta: Int)

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        manager.getAppWidgetIds(ComponentName(context, ClosingSoonWidget::class.java))
            .forEach { manager.updateAppWidget(it, closingSoon(context)) }
        manager.getAppWidgetIds(ComponentName(context, PollsWidget::class.java))
            .forEach { manager.updateAppWidget(it, polls(context)) }
    }

    fun closingSoon(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_closing_soon)
        val section = WidgetStore.current(context)?.optJSONObject("closingSoon")
        views.setTextViewText(
            R.id.widget_header_trailing,
            section?.optString("title")?.takeIf { it.isNotEmpty() }
                ?: context.getString(R.string.widget_closing_soon),
        )
        views.setOnClickPendingIntent(R.id.widget_root, open(context, section.link(), 10))
        val items = section?.optJSONArray("rows")
        val empty = items == null || items.length() == 0
        views.setViewVisibility(R.id.closing_empty, if (empty) View.VISIBLE else View.GONE)
        if (empty) {
            views.setTextViewText(
                R.id.closing_empty_line,
                section.empty() ?: context.getString(R.string.widget_closing_soon_empty),
            )
        }
        rows.forEachIndexed { i, row ->
            val item = items?.optJSONObject(i)
            if (item == null) {
                views.setViewVisibility(row.root, View.GONE)
                return@forEachIndexed
            }
            views.setViewVisibility(row.root, View.VISIBLE)
            views.setTextViewText(row.title, item.optString("title"))
            views.setTextViewText(row.meta, item.optString("meta"))
            WidgetStore.thumb(context, item.optString("thumb"))
                ?.let { views.setImageViewBitmap(row.thumb, it) }
            views.setOnClickPendingIntent(row.root, open(context, item.link(), 11 + i))
        }
        return views
    }

    fun polls(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_polls)
        val section = WidgetStore.current(context)?.optJSONObject("polls")
        views.setTextViewText(R.id.widget_header_trailing, "")
        val count = section?.optString("count").orEmpty()
        // A snapshot from before empty states existed says only "0".
        val empty = section.empty()
            ?: context.getString(R.string.widget_polls_empty)
                .takeIf { count.isEmpty() || count == "0" }
        val filled = if (empty == null) View.VISIBLE else View.GONE
        views.setViewVisibility(R.id.polls_count, filled)
        views.setViewVisibility(R.id.polls_label, filled)
        views.setViewVisibility(R.id.polls_empty, if (empty == null) View.GONE else View.VISIBLE)
        empty?.let { views.setTextViewText(R.id.polls_empty, it) }
        views.setTextViewText(R.id.polls_count, count)
        section?.optString("label")?.takeIf { it.isNotEmpty() }
            ?.let { views.setTextViewText(R.id.polls_label, it) }
        val line = if (empty == null) section?.optString("line").orEmpty() else ""
        views.setTextViewText(R.id.polls_line, line)
        views.setViewVisibility(R.id.polls_line, if (line.isEmpty()) View.GONE else View.VISIBLE)
        views.setOnClickPendingIntent(R.id.widget_root, open(context, section.link(), 20))
        return views
    }

    private fun JSONObject?.empty(): String? =
        this?.optString("empty")?.takeIf { it.isNotEmpty() }

    private fun JSONObject?.link(): String? =
        this?.optString("link")?.takeIf { it.startsWith("${SurfacesChannel.SCHEME}:") }

    private fun open(context: Context, link: String?, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            if (link != null) data = Uri.parse(link)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
