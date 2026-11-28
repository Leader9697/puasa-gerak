package com.faris.puasa_gerak

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/** Re-posts the stopwatch after a swipe, refreshes at target time, and restores everything after a reboot. */
class FastReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_DISMISSED = "com.faris.puasa_gerak.FAST_DISMISSED"
        const val ACTION_REFRESH = "com.faris.puasa_gerak.FAST_REFRESH"
        const val ACTION_TICK = "com.faris.puasa_gerak.FAST_TICK"
        private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    }

    override fun onReceive(c: Context, i: Intent) {
        val app = c.applicationContext
        val done = goAsync()
        scope.launch {
            try {
                // A minute tick only redraws the Nothing widgets; everything else refreshes all of it.
                if (i.action != ACTION_TICK) FastState.refreshAll(app)
                NothingWidgets.updateAll(app)
            } finally {
                done.finish()
            }
        }
    }
}
