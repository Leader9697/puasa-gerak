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

    /**
     * Start or end a fast from the home screen widget while the app is closed. The change is shown at once
     * and queued; the app applies the queue to its own data the next time it opens (see [takePending]).
     */
    @Synchronized
    fun toggleFromWidget(c: Context) {
        val s = load(c)
        val now = System.currentTimeMillis()
        val p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val queue = p.getString("pending", "") ?: ""
        if (s.mode == "fast") {
            // Same rule as the app: a fast keeps the streak at >= 80% of target and never under 13 hours.
            val hours = (now - s.start).toDouble() / HOUR
            val kept = hours >= s.target * 0.95 || hours >= maxOf(13.0, s.target * 0.8)
            save(c, "eat", s.start, s.target, now, s.plan, if (kept) s.streak + 1 else 0, s.notify)
            p.edit().putString("pending", "${queue}e:$now;").apply()
        } else {
            save(c, "fast", now, s.plan, s.lastEnd, s.plan, s.streak, s.notify)
            p.edit().putString("pending", "${queue}s:$now;").apply()
        }
    }

    fun hasPending(c: Context): Boolean =
        !(c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("pending", "") ?: "").isEmpty()

    /** Returns and clears the widget taps the app has not seen yet, e.g. "s:1732800000000;e:1732857600000;". */
    @Synchronized
    fun takePending(c: Context): String {
        val p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val q = p.getString("pending", "") ?: ""
        p.edit().remove("pending").apply()
        return q
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
        NothingWidgets.refresh(c)
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
