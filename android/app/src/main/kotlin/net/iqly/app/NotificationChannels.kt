package net.iqly.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

// Created natively so a remote push can name its channel before Dart runs.
// Ids match SurfaceChannel in lib/surfaces/notification_content.dart.
object NotificationChannels {
    private val channels = listOf(
        Triple("closing_soon", R.string.channel_closing_soon, R.string.channel_closing_soon_description),
        Triple("results", R.string.channel_results, R.string.channel_results_description),
        Triple("payouts", R.string.channel_payouts, R.string.channel_payouts_description),
        Triple("new_briefs", R.string.channel_new_briefs, R.string.channel_new_briefs_description),
        Triple("polls", R.string.channel_polls, R.string.channel_polls_description),
    )

    fun create(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannels(
            channels.map { (id, name, description) ->
                NotificationChannel(
                    id,
                    context.getString(name),
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply { this.description = context.getString(description) }
            },
        )
    }
}
