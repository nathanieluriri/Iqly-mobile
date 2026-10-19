package net.iqly.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

class ClosingSoonWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { manager.updateAppWidget(it, IqlyWidgets.closingSoon(context)) }
        IqlyWidgets.scheduleRefresh(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == IqlyWidgets.ACTION_REFRESH) {
            IqlyWidgets.updateAll(context)
        } else {
            super.onReceive(context, intent)
        }
    }
}

class PollsWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { manager.updateAppWidget(it, IqlyWidgets.polls(context)) }
        IqlyWidgets.scheduleRefresh(context)
    }
}

// Draws the snapshot as published; all wording and counting happens in Dart.
object IqlyWidgets {
    const val ACTION_REFRESH = "net.iqly.app.REFRESH_WIDGETS"

    private const val PAGE = 2

    // Less than this left and the countdown would tick past zero before the
    // redraw scheduled for the close, so the row keeps its published text.
    private const val LIVE_FLOOR_MS = 60_000L

    private val rows = listOf(
        Row(R.id.row_1, R.id.row_1_thumb, R.id.row_1_title, R.id.row_1_meta, R.id.row_1_live),
        Row(R.id.row_2, R.id.row_2_thumb, R.id.row_2_title, R.id.row_2_meta, R.id.row_2_live),
        Row(R.id.row_3, R.id.row_3_thumb, R.id.row_3_title, R.id.row_3_meta, R.id.row_3_live),
        Row(R.id.row_4, R.id.row_4_thumb, R.id.row_4_title, R.id.row_4_meta, R.id.row_4_live),
    )

    private data class Row(
        val root: Int,
        val thumb: Int,
        val title: Int,
        val meta: Int,
        val live: Int,
    )

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        manager.getAppWidgetIds(ComponentName(context, ClosingSoonWidget::class.java))
            .forEach { manager.updateAppWidget(it, closingSoon(context)) }
        manager.getAppWidgetIds(ComponentName(context, PollsWidget::class.java))
            .forEach { manager.updateAppWidget(it, polls(context)) }
        scheduleRefresh(context)
    }

    fun closingSoon(context: Context): RemoteViews {
        val now = System.currentTimeMillis()
        val section = WidgetStore.current(context, now)?.optJSONObject("closingSoon")
        val items = section?.optJSONArray("rows").objects().filter { it.isOpen(now) }
        // More than one page of briefs turns pages every 6 s (Figma 1340:28717).
        val paged = items.size > PAGE
        val views = RemoteViews(
            context.packageName,
            if (paged) R.layout.widget_closing_soon_pages else R.layout.widget_closing_soon,
        )
        views.setTextViewText(
            R.id.widget_header_trailing,
            section?.optString("title")?.takeIf { it.isNotEmpty() }
                ?: context.getString(R.string.widget_closing_soon),
        )
        views.setOnClickPendingIntent(R.id.widget_root, open(context, section.link(), 10))
        val empty = items.isEmpty()
        // The paged layout only exists with more than one page of briefs.
        if (!paged) {
            views.setViewVisibility(R.id.closing_empty, if (empty) View.VISIBLE else View.GONE)
            if (empty) {
                views.setTextViewText(
                    R.id.closing_empty_line,
                    section.empty() ?: context.getString(R.string.widget_closing_soon_empty),
                )
            }
        }
        rows.take(if (paged) rows.size else PAGE).forEachIndexed { i, row ->
            val item = items.getOrNull(i)
            if (item == null) {
                views.setViewVisibility(row.root, View.GONE)
                return@forEachIndexed
            }
            views.setViewVisibility(row.root, View.VISIBLE)
            views.setTextViewText(row.title, item.optString("title"))
            countdown(views, row.meta, row.live, item, item.optString("meta"), now)
            WidgetStore.thumb(context, item.optString("thumb"))
                ?.let { views.setImageViewBitmap(row.thumb, it) }
            views.setOnClickPendingIntent(row.root, open(context, item.link(), 11 + i))
        }
        return views
    }

    fun polls(context: Context): RemoteViews {
        val now = System.currentTimeMillis()
        val views = RemoteViews(context.packageName, R.layout.widget_polls)
        val section = WidgetStore.current(context, now)?.optJSONObject("polls")
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
        val open = section?.takeIf { empty == null && it.isOpen(now) }
        countdown(views, R.id.polls_line, R.id.polls_live, open, open?.optString("line").orEmpty(), now)
        views.setOnClickPendingIntent(R.id.widget_root, open(context, section.link(), 20))
        return views
    }

    // Wakes the widgets for the next hourly snapshot or the next close,
    // whichever comes first. Inexact, so it costs no battery permission.
    fun scheduleRefresh(context: Context) {
        val at = WidgetStore.nextChange(context, System.currentTimeMillis()) ?: return
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val intent = Intent(context, ClosingSoonWidget::class.java).setAction(ACTION_REFRESH)
        val pending = PendingIntent.getBroadcast(
            context,
            30,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarms.set(AlarmManager.RTC, at, pending)
    }

    // A brief closing within a day counts down live: "%s" in its live text
    // is where the time goes (Figma 1340:28510).
    private fun countdown(
        views: RemoteViews,
        staticId: Int,
        liveId: Int,
        item: JSONObject?,
        text: String,
        now: Long,
    ) {
        val left = (item?.optLong("closesAt") ?: 0L) - now
        val format = item?.optString("live").orEmpty()
        if (left > LIVE_FLOOR_MS && format.contains("%s")) {
            views.setViewVisibility(staticId, View.GONE)
            views.setViewVisibility(liveId, View.VISIBLE)
            views.setChronometer(liveId, SystemClock.elapsedRealtime() + left, format, true)
            views.setChronometerCountDown(liveId, true)
        } else {
            views.setViewVisibility(liveId, View.GONE)
            views.setViewVisibility(staticId, if (text.isEmpty()) View.GONE else View.VISIBLE)
            views.setTextViewText(staticId, text)
        }
    }

    private fun JSONObject.isOpen(now: Long): Boolean {
        val closesAt = optLong("closesAt")
        return closesAt == 0L || closesAt > now
    }

    private fun JSONArray?.objects(): List<JSONObject> =
        if (this == null) emptyList() else (0 until length()).mapNotNull { optJSONObject(it) }

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
