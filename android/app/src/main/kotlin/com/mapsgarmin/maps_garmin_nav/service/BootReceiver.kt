package com.mapsgarmin.maps_garmin_nav.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Settings
import com.mapsgarmin.maps_garmin_nav.garmin.ConnectIqBridge

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) {
            return
        }
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ).orEmpty()
        if (context.packageName in enabled) {
            ConnectIqBridge.get(context).ensureInitialized(showUi = false)
            NavForegroundService.start(context)
        }
    }
}
