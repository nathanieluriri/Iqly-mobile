package net.iqly.app

import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.onesignal.notifications.INotificationReceivedEvent
import com.onesignal.notifications.INotificationServiceExtension
import org.json.JSONObject

// Styles every push the way lib/surfaces/surfaces.dart styles a local
// notification, even when the app is not running. The API sends the extras
// in the push data (apps/push-worker in iqly-platform).
class IqlyPushExtension : INotificationServiceExtension {
    override fun onNotificationReceived(event: INotificationReceivedEvent) {
        val notification = event.notification
        val data = notification.additionalData ?: JSONObject()
        val context = event.context
        val body = notification.body.orEmpty()
        notification.setExtender(
            NotificationCompat.Extender { builder ->
                builder
                    .setSmallIcon(R.drawable.ic_stat_iqly)
                    .setColor(ContextCompat.getColor(context, R.color.iq_accent))
                    .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                data.optString("subtext").takeIf { it.isNotEmpty() }?.let(builder::setSubText)

                val countdownTo = data.optLong("countdownTo", 0L)
                if (countdownTo > System.currentTimeMillis()) {
                    builder
                        .setWhen(countdownTo)
                        .setShowWhen(true)
                        .setUsesChronometer(true)
                        .setChronometerCountDown(true)
                        .setTimeoutAfter(countdownTo - System.currentTimeMillis())
                }

                val max = data.optInt("progressMax", 0)
                if (max > 0) {
                    val progress = data.optInt("progress", 0)
                    builder
                        .setProgress(max, progress, false)
                        .setShowWhen(false)
                        .setOngoing(progress < max)
                        .setOnlyAlertOnce(true)
                        .setCategory(NotificationCompat.CATEGORY_PROGRESS)
                }

                if (data.optBoolean("private", false)) {
                    builder
                        .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                        .setPublicVersion(
                            NotificationCompat.Builder(context, "")
                                .setSmallIcon(R.drawable.ic_stat_iqly)
                                .setColor(ContextCompat.getColor(context, R.color.iq_accent))
                                .setContentTitle(context.getString(R.string.app_name))
                                .setContentText(data.optString("publicText"))
                                .build(),
                        )
                }
                builder
            },
        )
    }
}
