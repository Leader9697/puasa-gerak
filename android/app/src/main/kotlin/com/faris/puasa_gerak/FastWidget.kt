package com.faris.puasa_gerak

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews

/** Home screen widget: a live fasting stopwatch that ticks on its own. */
class FastWidget : AppWidgetProvider() {
    override fun onUpdate(c: Context, m: AppWidgetManager, ids: IntArray) {
        for (id in ids) m.updateAppWidget(id, build(c))
    }

    companion object {
        fun updateAll(c: Context) {
            val m = AppWidgetManager.getInstance(c)
            val ids = m.getAppWidgetIds(ComponentName(c, FastWidget::class.java))
            if (ids.isEmpty()) return
            val v = build(c)
            for (id in ids) m.updateAppWidget(id, v)
        }

        private fun build(c: Context): RemoteViews {
            val s = FastState.load(c)
            val v = RemoteViews(c.packageName, R.layout.fast_widget)
            val now = System.currentTimeMillis()
            val open = PendingIntent.getActivity(
                c, 0, Intent(c, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            v.setOnClickPendingIntent(R.id.w_root, open)
            v.setTextViewText(R.id.w_streak, "🔥 ${s.streak}")
            fun clock(since: Long) {
                v.setViewVisibility(R.id.w_clock, View.VISIBLE)
                v.setViewVisibility(R.id.w_idle, View.GONE)
                v.setChronometer(R.id.w_clock, SystemClock.elapsedRealtime() - (now - since), null, true)
            }
            when {
                s.mode == "fast" -> {
                    val done = now >= s.end
                    v.setInt(R.id.w_root, "setBackgroundResource", if (done) R.drawable.widget_bg_green else R.drawable.widget_bg_orange)
                    v.setTextViewText(R.id.w_label, "PUASA ${s.target}:${24 - s.target}")
                    clock(s.start)
                    v.setTextViewText(R.id.w_sub, if (done) "Target tercapai! ✓" else "Selesai jam ${FastState.hm(s.end)}")
                }
                s.mode == "eat" && now < s.lastEnd + 36 * FastState.HOUR -> {
                    v.setInt(R.id.w_root, "setBackgroundResource", R.drawable.widget_bg_blue)
                    v.setTextViewText(R.id.w_label, "JENDELA MAKAN")
                    clock(s.lastEnd)
                    v.setTextViewText(R.id.w_sub, if (now < s.eatEnd) "Puasa lagi jam ${FastState.hm(s.eatEnd)}" else "Waktunya mulai puasa")
                }
                else -> {
                    v.setInt(R.id.w_root, "setBackgroundResource", R.drawable.widget_bg_orange)
                    v.setTextViewText(R.id.w_label, "PUASA & GERAK")
                    v.setChronometer(R.id.w_clock, SystemClock.elapsedRealtime(), null, false)
                    v.setViewVisibility(R.id.w_clock, View.GONE)
                    v.setViewVisibility(R.id.w_idle, View.VISIBLE)
                    v.setTextViewText(R.id.w_sub, "Ketuk untuk mulai puasa ${s.plan} jam")
                }
            }
            return v
        }
    }
}
