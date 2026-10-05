package net.iqly.iqly_mobile

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// FlutterFragmentActivity, not FlutterActivity: local_auth's BiometricPrompt
// needs a FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {
    private var surfaces: SurfacesChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        NotificationChannels.create(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        surfaces = SurfacesChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
            SurfacesChannel.link(intent),
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        surfaces?.open(intent)
    }
}
