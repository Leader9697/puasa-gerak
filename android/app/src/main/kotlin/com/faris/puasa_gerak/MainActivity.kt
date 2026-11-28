package com.faris.puasa_gerak

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required for the Health Connect permission dialog.
class MainActivity : FlutterFragmentActivity() {
    companion object {
        const val ACTION_OPEN_FAST = "com.faris.puasa_gerak.OPEN_FAST"
    }

    private var channel: MethodChannel? = null
    /** Set when the widget asked to open the fasting tab before Flutter was listening. */
    private var openFast = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        openFast = openFast || intent?.action == ACTION_OPEN_FAST
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "puasa/native")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "sync" -> {
                    // Widget taps the app has not applied yet win over the app's older copy.
                    if (FastState.hasPending(this)) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val a = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                    FastState.save(
                        this,
                        mode = a["mode"] as? String ?: "idle",
                        start = (a["start"] as? Number)?.toLong() ?: 0L,
                        target = (a["target"] as? Number)?.toInt() ?: 16,
                        lastEnd = (a["lastEnd"] as? Number)?.toLong() ?: 0L,
                        plan = (a["plan"] as? Number)?.toInt() ?: 16,
                        streak = (a["streak"] as? Number)?.toInt() ?: 0,
                        notify = a["notify"] as? Boolean ?: true,
                    )
                    FastState.refreshAll(this)
                    result.success(true)
                }
                "takePending" -> result.success(FastState.takePending(this))
                "takeOpen" -> {
                    result.success(openFast)
                    openFast = false
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == ACTION_OPEN_FAST) {
            val ch = channel
            if (ch != null) ch.invokeMethod("openFast", null) else openFast = true
        }
    }
}
