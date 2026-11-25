package com.faris.puasa_gerak

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required for the Health Connect permission dialog.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "puasa/native").setMethodCallHandler { call, result ->
            when (call.method) {
                "sync" -> {
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
                else -> result.notImplemented()
            }
        }
    }
}
