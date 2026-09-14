package com.mapsgarmin.maps_garmin_nav.garmin

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.mapsgarmin.maps_garmin_nav.service.NavForegroundService

class IncomingMessageReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        ConnectIqBridge.get(context).ensureInitialized(showUi = false)
        NavForegroundService.start(context)
    }
}
