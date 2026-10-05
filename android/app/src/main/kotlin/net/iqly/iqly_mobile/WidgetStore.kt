package net.iqly.iqly_mobile

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import org.json.JSONObject
import java.io.File

// The hourly snapshots the app publishes (WidgetTimeline in
// lib/surfaces/widget_snapshot.dart) and the thumbnails it painted.
object WidgetStore {
    private const val PREFS = "iqly_surfaces"
    private const val KEY = "widget_timeline"
    private const val DIR = "surfaces"

    fun save(context: Context, timeline: String, thumbs: Map<String, ByteArray>) {
        val dir = File(context.filesDir, DIR).apply { mkdirs() }
        thumbs.forEach { (name, bytes) -> File(dir, File(name).name).writeBytes(bytes) }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY, timeline)
            .apply()
    }

    fun current(context: Context, now: Long = System.currentTimeMillis()): JSONObject? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null) ?: return null
        val entries = try {
            JSONObject(raw).getJSONArray("entries")
        } catch (e: org.json.JSONException) {
            return null
        }
        var picked: JSONObject? = null
        for (i in 0 until entries.length()) {
            val entry = entries.getJSONObject(i)
            if (entry.optLong("at") <= now) picked = entry
        }
        return picked ?: if (entries.length() > 0) entries.getJSONObject(0) else null
    }

    fun thumb(context: Context, name: String): Bitmap? {
        val file = File(File(context.filesDir, DIR), File(name).name)
        return if (file.exists()) BitmapFactory.decodeFile(file.path) else null
    }
}
