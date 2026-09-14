package com.mapsgarmin.maps_garmin_nav.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.mapsgarmin.maps_garmin_nav.MainActivity
import com.mapsgarmin.maps_garmin_nav.R
import com.mapsgarmin.maps_garmin_nav.garmin.ConnectIqBridge
import com.mapsgarmin.maps_garmin_nav.nav.NavEvent
import com.mapsgarmin.maps_garmin_nav.nav.NavEventBus
import com.mapsgarmin.maps_garmin_nav.nav.NavPayload

class NavForegroundService : Service() {
    private val listener: (NavEvent) -> Unit = { event ->
        if (event is NavEvent.Nav) {
            updateNotification(event.payload)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
        startInForeground(NavEventBus.lastNav)
        NavEventBus.addListener(listener)
        ConnectIqBridge.get(this).ensureInitialized(showUi = false)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        updateNotification(NavEventBus.lastNav)
        return START_STICKY
    }

    override fun onDestroy() {
        NavEventBus.removeListener(listener)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startInForeground(payload: NavPayload) {
        val notification = buildNotification(payload)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(payload: NavPayload) {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(payload))
    }

    private fun buildNotification(payload: NavPayload): Notification {
        val launch = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val text = when (payload.status) {
            NavPayload.STATUS_NAVIGATING ->
                listOf(payload.distance, payload.instruction, payload.road)
                    .filter { it.isNotBlank() }
                    .distinct()
                    .joinToString(" · ")
                    .ifBlank { getString(R.string.nav_notification_idle) }
            NavPayload.STATUS_REROUTING -> "Rerouting"
            else -> getString(R.string.nav_notification_idle)
        }
        return NotificationCompat.Builder(this, getString(R.string.nav_channel_id))
            .setContentTitle(getString(R.string.nav_notification_title))
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_map)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(launch)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun createChannel() {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            getString(R.string.nav_channel_id),
            getString(R.string.nav_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.description = getString(R.string.nav_channel_desc)
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val NOTIFICATION_ID = 42

        fun start(context: Context) {
            val intent = Intent(context, NavForegroundService::class.java)
            context.startForegroundService(intent)
        }
    }
}
