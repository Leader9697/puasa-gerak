package com.faris.puasa_gerak

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Re-posts the stopwatch after a swipe, refreshes at target time, and restores everything after a reboot. */
class FastReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_DISMISSED = "com.faris.puasa_gerak.FAST_DISMISSED"
        const val ACTION_REFRESH = "com.faris.puasa_gerak.FAST_REFRESH"
    }

    override fun onReceive(c: Context, i: Intent) {
        FastState.refreshAll(c)
    }
}
