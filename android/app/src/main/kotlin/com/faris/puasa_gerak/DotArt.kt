package com.faris.puasa_gerak

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Draws the Nothing-style dot-matrix parts of the widget: digits from a 5x7 dot font and a ring of dots.
 * Drawn as small bitmaps so no font file (Ndot/Doto) has to ship with the app.
 */
object DotArt {
    const val RED = 0xFFD71921.toInt()
    const val WHITE = 0xFFFFFFFF.toInt()
    const val OFF = 0xFF2A2A2A.toInt()

    private val FONT = mapOf(
        '0' to arrayOf("01110", "10001", "10011", "10101", "11001", "10001", "01110"),
        '1' to arrayOf("00100", "01100", "00100", "00100", "00100", "00100", "01110"),
        '2' to arrayOf("01110", "10001", "00001", "00010", "00100", "01000", "11111"),
        '3' to arrayOf("11111", "00010", "00100", "00010", "00001", "10001", "01110"),
        '4' to arrayOf("00010", "00110", "01010", "10010", "11111", "00010", "00010"),
        '5' to arrayOf("11111", "10000", "11110", "00001", "00001", "10001", "01110"),
        '6' to arrayOf("00110", "01000", "10000", "11110", "10001", "10001", "01110"),
        '7' to arrayOf("11111", "00001", "00010", "00100", "01000", "01000", "01000"),
        '8' to arrayOf("01110", "10001", "10001", "01110", "10001", "10001", "01110"),
        '9' to arrayOf("01110", "10001", "10001", "01111", "00001", "00010", "01100"),
        ':' to arrayOf("0", "0", "1", "0", "1", "0", "0"),
        '-' to arrayOf("000", "000", "000", "111", "000", "000", "000"),
        '%' to arrayOf("11000", "11001", "00010", "00100", "01000", "10011", "00011"),
    )

    /** Width of [text] in dot pitches (rows are always 7 pitches tall). */
    fun cols(text: String): Int = text.sumOf { (FONT[it]?.get(0)?.length ?: 3) + 1 } - 1

    /** Renders [text] with [pitch] pixels between dot centres. */
    fun digits(text: String, pitch: Float, color: Int = WHITE): Bitmap {
        val w = (cols(text) * pitch).roundToInt().coerceAtLeast(1)
        val h = (7 * pitch).roundToInt().coerceAtLeast(1)
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
        val r = pitch * 0.41f
        var x = 0f
        for (ch in text) {
            val g = FONT[ch]
            if (g == null) {
                x += 4 * pitch
                continue
            }
            for ((row, bits) in g.withIndex()) {
                for ((col, b) in bits.withIndex()) {
                    if (b == '1') c.drawCircle(x + col * pitch + pitch / 2, row * pitch + pitch / 2, r, p)
                }
            }
            x += (g[0].length + 1) * pitch
        }
        return bmp
    }

    /**
     * Ring of [n] dots, filled clockwise from 12 o'clock. Filled dots are white, the newest one red and a
     * bit larger, the rest dark grey.
     */
    fun ring(size: Int, n: Int, frac: Float, dot: Float): Bitmap {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        val lit = (frac.coerceIn(0f, 1f) * n).roundToInt()
        val big = dot * 1.3f
        val radius = size / 2f - big - 1f
        for (i in 0 until n) {
            val a = -PI / 2 + 2 * PI * i / n
            val x = size / 2f + (radius * cos(a)).toFloat()
            val y = size / 2f + (radius * sin(a)).toFloat()
            val last = i == lit - 1
            p.color = when {
                last -> RED
                i < lit -> WHITE
                else -> OFF
            }
            c.drawCircle(x, y, if (last) big else dot, p)
        }
        return bmp
    }

    /** A single round dot (status light). */
    fun dot(size: Int, color: Int): Bitmap {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        Canvas(bmp).drawCircle(size / 2f, size / 2f, size / 2f, Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color })
        return bmp
    }
}
