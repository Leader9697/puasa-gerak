package com.faris.puasa_gerak

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/** Ongoing stopwatch notification while fasting. If the user swipes it away it is posted again. */
object FastNotification {
    private const val CHANNEL = "fast_timer"
    private const val ID = 4201

    private fun channel(c: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = c.getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(CHANNEL) == null) {
                val ch = NotificationChannel(CHANNEL, "Stopwatch puasa", NotificationManager.IMPORTANCE_LOW)
                ch.description = "Menampilkan lama puasa yang sedang berjalan"
                ch.setShowBadge(false)
                nm.createNotificationChannel(ch)
            }
        }
    }

    fun show(c: Context, s: FastState.S) {
        channel(c)
        val now = System.currentTimeMillis()
        val done = now >= s.end
        val open = PendingIntent.getActivity(
            c, 0, Intent(c, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val again = PendingIntent.getBroadcast(
            c, 1, Intent(c, FastReceiver::class.java).setAction(FastReceiver.ACTION_DISMISSED),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, CHANNEL) else Notification.Builder(c)
        val pct = (((now - s.start).toDouble() / (s.end - s.start)) * 100).toInt().coerceIn(0, 100)
        b.setSmallIcon(R.drawable.ic_stat_timer)
            .setContentTitle(if (done) "Target ${s.target} jam tercapai! Lanjut atau buka puasa" else "Sedang puasa ${s.target}:${24 - s.target}")
            .setContentText(if (done) "Mulai ${FastState.hm(s.start)} · buka aplikasi untuk mencatat" else "Mulai ${FastState.hm(s.start)} · target selesai ${FastState.hm(s.end)}")
            .setSubText(if (s.streak > 0) "🔥 ${s.streak} hari" else null)
            .setWhen(s.start)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_STOPWATCH)
            .setColor(if (done) 0xFF0E9461.toInt() else 0xFFE8590C.toInt())
            .setProgress(100, pct, false)
            .setContentIntent(open)
            .setDeleteIntent(again)
        if (Build.VERSION.SDK_INT >= 31) b.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        val n = b.build()
        n.flags = n.flags or Notification.FLAG_NO_CLEAR or Notification.FLAG_ONGOING_EVENT
        c.getSystemService(NotificationManager::class.java).notify(ID, n)
    }

    fun cancel(c: Context) {
        c.getSystemService(NotificationManager::class.java).cancel(ID)
    }
}
