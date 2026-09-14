package com.mapsgarmin.maps_garmin_nav.nav

import android.os.Handler
import android.os.HandlerThread
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.mapsgarmin.maps_garmin_nav.garmin.ConnectIqBridge
import com.mapsgarmin.maps_garmin_nav.service.NavForegroundService

class MapsNavListenerService : NotificationListenerService() {
    private val parser by lazy { MapsNotificationParser(applicationContext) }
    private val workerThread = HandlerThread("maps-nav-parser").apply { start() }
    private val worker = Handler(workerThread.looper)
    private var pendingParse: Runnable? = null

    override fun onListenerConnected() {
        super.onListenerConnected()
        ConnectIqBridge.get(this).ensureInitialized(showUi = false)
        try {
            activeNotifications?.forEach { onNotificationPosted(it) }
        } catch (_: Exception) {
            // Listener can be connected before notification access is fully usable.
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) {
            return
        }
        pendingParse?.let { worker.removeCallbacks(it) }
        val task = Runnable {
            val payload = parser.parse(sbn) ?: return@Runnable
            publish(payload)
        }
        pendingParse = task
        worker.postDelayed(task, DEBOUNCE_MS)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        if (sbn == null) {
            return
        }
        val payload = parser.parse(sbn)
        if (payload != null || sbn.packageName.contains("maps")) {
            pendingParse?.let { worker.removeCallbacks(it) }
            publish(NavPayload.ended)
        }
    }

    override fun onDestroy() {
        workerThread.quitSafely()
        super.onDestroy()
    }

    private fun publish(payload: NavPayload) {
        if (payload == NavEventBus.lastNav) {
            return
        }
        NavEventBus.emitNav(payload)
        ConnectIqBridge.get(this).send(payload)
        NavForegroundService.start(this)
    }

    companion object {
        private const val DEBOUNCE_MS = 500L
    }
}
