package com.faris.puasa_gerak

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle

/**
 * "Widget settings" from the launcher's long-press menu (Android 12+, reconfigurable widgets).
 * Android widgets cannot handle a long press themselves, so this is the long-press route: it opens the
 * fasting tab, where the schedule (14:10, 16:8, ...) is chosen.
 */
class NothingWidgetSettings : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val id = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id))
        startActivity(NothingWidgets.openIntent(this))
        NothingWidgets.refresh(this)
        finish()
    }
}
