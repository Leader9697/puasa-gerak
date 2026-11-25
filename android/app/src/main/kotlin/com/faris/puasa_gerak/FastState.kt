package com.faris.puasa_gerak

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import java.util.Calendar

/** Fasting state mirrored from the Flutter app, so the notification and widget work without the app running. */
object FastState {
    private const val PREFS = "fast_native"
    const val HOUR = 3_600_000L

    data class S(
        val mode: String, val start: Long, val target: Int, val lastEnd: Long,
        val plan: Int, val streak: Int, val notify: Boolean,
    ) {
        val end: Long get() = start + target * HOUR
        val eatEnd: Long get() = lastEnd + (24 - plan) * HOUR
    }

    fun save(
        c: Context, mode: String, start: Long, target: Int, lastEnd: Long,
        plan: Int, streak: Int, notify: Boolean,
    ) {
        c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("mode", mode).putLong("start", start).putInt("target", target)
            .putLong("lastEnd", lastEnd).putInt("plan", plan).putInt("streak", streak)
            .putBoolean("notify", notify).apply()
    }

    fun load(c: Context): S {
        val p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return S(
            p.getString("mode", "idle") ?: "idle", p.getLong("start", 0L), p.getInt("target", 16),
            p.getLong("lastEnd", 0L), p.getInt("plan", 16), p.getInt("streak", 0), p.getBoolean("notify", true),
        )
    }

    fun hm(t: Long): String {
        val c = Calendar.getInstance().apply { timeInMillis = t }
        return String.format("%02d.%02d", c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE))
    }

    /** Updates the ongoing notification and every widget, and plans the next refresh. */
    fun refreshAll(c: Context) {
        val s = load(c)
        try {
            if (s.mode == "fast" && s.notify) FastNotification.show(c, s) else FastNotification.cancel(c)
        } catch (_: Exception) {
        }
        FastWidget.updateAll(c)
        scheduleRefresh(c, s)
    }

    private fun scheduleRefresh(c: Context, s: S) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = PendingIntent.getBroadcast(
            c, 7, Intent(c, FastReceiver::class.java).setAction(FastReceiver.ACTION_REFRESH),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        am.cancel(pi)
        val now = System.currentTimeMillis()
        val next = when {
            s.mode == "fast" && s.end > now -> s.end
            s.mode == "eat" && s.eatEnd > now -> s.eatEnd
            else -> 0L
        }
        if (next > 0) am.set(AlarmManager.RTC, next + 1000, pi)
    }
}
