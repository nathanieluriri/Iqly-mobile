package net.iqly.iqly_mobile

import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class SurfacesChannel(
    private val context: Context,
    messenger: BinaryMessenger,
    private var launchLink: String?,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, NAME)

    init {
        channel.setMethodCallHandler(this)
    }

    fun open(intent: Intent?) {
        link(intent)?.let { channel.invokeMethod("openLink", it) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "publishWidgets" -> {
                val timeline = call.argument<Map<String, Any?>>("timeline")
                val thumbs = call.argument<Map<String, ByteArray>>("thumbs").orEmpty()
                if (timeline == null) {
                    result.success(false)
                    return
                }
                WidgetStore.save(context, JSONObject(timeline).toString(), thumbs)
                IqlyWidgets.updateAll(context)
                result.success(true)
            }
            "takeLaunchLink" -> {
                result.success(launchLink)
                launchLink = null
            }
            // Android shows the payout as a progress notification instead.
            "payoutActivity", "endPayoutActivity" -> result.success(false)
            else -> result.notImplemented()
        }
    }

    companion object {
        const val NAME = "net.iqly/surfaces"
        const val SCHEME = "iqly"

        fun link(intent: Intent?): String? {
            val data = intent?.data ?: return null
            return if (data.scheme == SCHEME) data.toString() else null
        }
    }
}
