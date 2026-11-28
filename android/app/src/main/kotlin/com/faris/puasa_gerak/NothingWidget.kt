package com.faris.puasa_gerak

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.ActionParameters
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlin.math.ceil
import kotlin.math.min

/*
 * Nothing OS style fasting widget (Jetpack Glance), in two sizes:
 *  - 4x2: dot ring + percent, status, big dot-matrix countdown, start/end/target, streak
 *  - 2x2: dot ring with the countdown inside
 * Tap = start or end a fast. Tapping the start/end/target row opens the fasting tab; on Android 12+ a long
 * press shows the launcher's "widget settings" button, which opens the same place.
 * Updates once a minute with a non-waking alarm, so it only redraws while the phone is awake.
 */

private val CARD = Color(0xFF0E0E0E)
private val INK = Color(0xFFFFFFFF)
private val GREY = Color(0xFF8A8A8A)
private val DIM = Color(0xFF6A6A6A)

/** What the widget shows at one moment. */
data class FastView(
    val status: String, val label: String, val count: String, val frac: Float,
    val start: String, val end: String, val target: String, val streak: Int, val fasting: Boolean,
) {
    val pct: Int get() = (frac * 100).toInt().coerceIn(0, 100)

    companion object {
        private fun hhmm(ms: Long): String {
            val m = (ms / 60_000L).coerceAtLeast(0)
            return String.format("%02d:%02d", (m / 60).coerceAtMost(99), m % 60)
        }

        /** Minutes left, rounded up, so the countdown reaches 00:00 exactly at the target. */
        private fun left(ms: Long) = hhmm((ceil(ms / 60_000.0) * 60_000).toLong())

        fun of(s: FastState.S, now: Long): FastView {
            val plan = "${s.plan}:${24 - s.plan}"
            return when {
                s.mode == "fast" -> {
                    val dur = (s.end - s.start).toFloat()
                    val rem = s.end - now
                    FastView(
                        status = if (rem > 0) "PUASA" else "TERCAPAI",
                        label = if (rem > 0) "SISA WAKTU PUASA" else "LEWAT DARI TARGET",
                        count = if (rem > 0) left(rem) else hhmm(-rem),
                        frac = ((now - s.start) / dur).coerceIn(0f, 1f),
                        start = FastState.hm(s.start), end = FastState.hm(s.end),
                        target = "${s.target}:${24 - s.target}", streak = s.streak, fasting = true,
                    )
                }
                s.mode == "eat" && now < s.lastEnd + 36 * FastState.HOUR -> {
                    val dur = (s.eatEnd - s.lastEnd).toFloat().coerceAtLeast(1f)
                    val rem = s.eatEnd - now
                    FastView(
                        status = if (rem > 0) "MAKAN" else "WAKTUNYA PUASA",
                        label = if (rem > 0) "SAMPAI PUASA LAGI" else "KETUK UNTUK MULAI",
                        count = if (rem > 0) left(rem) else "00:00",
                        frac = ((now - s.lastEnd) / dur).coerceIn(0f, 1f),
                        start = FastState.hm(s.lastEnd), end = FastState.hm(s.eatEnd),
                        target = plan, streak = s.streak, fasting = false,
                    )
                }
                else -> FastView(
                    status = "SIAP", label = "KETUK UNTUK MULAI", count = "--:--", frac = 0f,
                    start = "--.--", end = "--.--", target = plan, streak = s.streak, fasting = false,
                )
            }
        }
    }
}

abstract class NothingFastWidget(private val compact: Boolean) : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        NothingTicker.schedule(context)
        provideContent {
            // Reading the tick makes a running session redraw when the minute changes.
            val tick by NothingWidgets.tick.collectAsState()
            val v = FastView.of(FastState.load(context), maxOf(tick, System.currentTimeMillis()))
            val scale = min(context.resources.displayMetrics.density, 3f)
            if (compact) Small(context, v, scale) else Wide(context, v, scale)
        }
    }
}

class NothingFastWide : NothingFastWidget(false)
class NothingFastSmall : NothingFastWidget(true)

class NothingWideReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = NothingFastWide()
}

class NothingSmallReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = NothingFastSmall()
}

/** Tap on the widget: start a fast, or end the running one. */
class ToggleFastAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        FastState.toggleFromWidget(context)
        FastState.refreshAll(context)
        NothingWidgets.updateAll(context)
    }
}

object NothingWidgets {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    val tick = MutableStateFlow(0L)

    suspend fun updateAll(c: Context) {
        tick.value = System.currentTimeMillis()
        try {
            NothingFastWide().updateAll(c)
            NothingFastSmall().updateAll(c)
        } catch (_: Exception) {
        }
        NothingTicker.schedule(c)
    }

    fun refresh(c: Context) {
        val app = c.applicationContext
        scope.launch { updateAll(app) }
    }

    fun count(c: Context): Int {
        val m = AppWidgetManager.getInstance(c)
        return m.getAppWidgetIds(ComponentName(c, NothingWideReceiver::class.java)).size +
            m.getAppWidgetIds(ComponentName(c, NothingSmallReceiver::class.java)).size
    }

    /** Opens the app on the fasting tab (schedule presets). */
    fun openIntent(c: Context): Intent =
        Intent(c, MainActivity::class.java)
            .setAction(MainActivity.ACTION_OPEN_FAST)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
}

/**
 * Minute ticks for the countdown. Uses RTC (not RTC_WAKEUP): while the screen is off the phone sleeps and
 * the tick waits, so the widget only redraws when someone can see it.
 */
object NothingTicker {
    fun schedule(c: Context) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = PendingIntent.getBroadcast(
            c, 11, Intent(c, FastReceiver::class.java).setAction(FastReceiver.ACTION_TICK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val s = FastState.load(c)
        val now = System.currentTimeMillis()
        val live = s.mode == "fast" || (s.mode == "eat" && now < s.lastEnd + 36 * FastState.HOUR)
        if (!live || NothingWidgets.count(c) == 0) {
            am.cancel(pi)
            return
        }
        val next = (now / 60_000L + 1) * 60_000L + 500L
        try {
            if (Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()) am.setExact(AlarmManager.RTC, next, pi)
            else am.set(AlarmManager.RTC, next, pi)
        } catch (_: SecurityException) {
            am.set(AlarmManager.RTC, next, pi)
        }
    }
}

// ---------------------------------------------------------------- layouts

private fun txt(size: Float, color: Color = INK, bold: Boolean = false) =
    TextStyle(color = ColorProvider(color), fontSize = size.sp, fontWeight = if (bold) FontWeight.Medium else FontWeight.Normal)

@Composable
private fun Bmp(b: Bitmap, w: Dp, h: Dp, desc: String?, modifier: GlanceModifier = GlanceModifier) {
    Image(ImageProvider(b), desc, modifier.size(w, h), contentScale = ContentScale.Fit)
}

/** Dot-matrix text sized to a height in dp. */
@Composable
private fun Digits(text: String, h: Dp, scale: Float, desc: String? = null) {
    val pitchDp = h.value / 7f
    val bmp = DotArt.digits(text, pitchDp * scale)
    Bmp(bmp, (DotArt.cols(text) * pitchDp).dp, h, desc ?: text)
}

@Composable
private fun StatusLine(v: FastView, scale: Float, size: Float) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Bmp(DotArt.dot((8 * scale).toInt(), if (v.fasting) DotArt.RED else DotArt.WHITE), 7.dp, 7.dp, null)
        Spacer(GlanceModifier.width(7.dp))
        Text(v.status, style = txt(size, INK, bold = true), maxLines = 1)
    }
}

private fun cardModifier(c: Context) = GlanceModifier
    .fillMaxSize()
    .appWidgetBackground()
    .cornerRadius(24.dp)
    .background(CARD)
    .clickable(actionRunCallback<ToggleFastAction>())

@Composable
private fun Wide(c: Context, v: FastView, scale: Float) {
    val size = LocalSize.current
    val pad = 14.dp
    val ringDp = min(size.height.value - 2 * pad.value, size.width.value * 0.42f).coerceAtLeast(60f)
    val rightW = size.width.value - ringDp - 2 * pad.value - 16f
    // Countdown "06:12" is 25 dot pitches wide and 7 tall.
    val digitH = min(rightW / 25f * 7f, size.height.value * 0.27f).coerceAtLeast(18f)

    Box(cardModifier(c).padding(pad)) {
        Row(GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
            Box(GlanceModifier.size(ringDp.dp), contentAlignment = Alignment.Center) {
                Bmp(DotArt.ring((ringDp * scale).toInt(), 36, v.frac, 2.6f * scale * ringDp / 128f), ringDp.dp, ringDp.dp, "${v.pct} persen")
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Digits("${v.pct}%", (ringDp * 0.16f).dp, scale)
                    Spacer(GlanceModifier.height(4.dp))
                    Text(v.target, style = txt(9f, GREY), maxLines = 1)
                }
            }
            Spacer(GlanceModifier.width(16.dp))
            Column(GlanceModifier.defaultWeight().fillMaxHeight()) {
                Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    StatusLine(v, scale, 11f)
                    Spacer(GlanceModifier.defaultWeight())
                    Text("${v.streak} HARI", style = txt(10f, GREY), maxLines = 1)
                }
                Spacer(GlanceModifier.height(8.dp))
                Digits(v.count, digitH.dp, scale, "${v.label} ${v.count}")
                Spacer(GlanceModifier.height(5.dp))
                Text(v.label, style = txt(8.5f, GREY), maxLines = 1)
                Spacer(GlanceModifier.defaultWeight())
                Row(
                    GlanceModifier.clickable(actionStartActivity(NothingWidgets.openIntent(c))),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Info("MULAI", v.start)
                    Spacer(GlanceModifier.width(18.dp))
                    Info("SELESAI", v.end)
                    Spacer(GlanceModifier.width(18.dp))
                    Info("TARGET", v.target)
                }
            }
        }
    }
}

@Composable
private fun Info(k: String, value: String) {
    Column {
        Text(k, style = txt(7.5f, DIM), maxLines = 1)
        Text(value, style = txt(12f, INK, bold = true), maxLines = 1)
    }
}

@Composable
private fun Small(c: Context, v: FastView, scale: Float) {
    val size = LocalSize.current
    val ringDp = (min(size.width.value, size.height.value) - 12f).coerceAtLeast(60f)
    Box(cardModifier(c), contentAlignment = Alignment.Center) {
        Bmp(DotArt.ring((ringDp * scale).toInt(), 36, v.frac, 2.4f * scale * ringDp / 136f), ringDp.dp, ringDp.dp, "${v.pct} persen")
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            StatusLine(v, scale, 9f)
            Spacer(GlanceModifier.height(6.dp))
            Digits(v.count, (ringDp * 0.2f).dp, scale, "${v.label} ${v.count}")
            Spacer(GlanceModifier.height(6.dp))
            Text(v.label, style = txt(7.5f, GREY), maxLines = 1)
        }
    }
}
