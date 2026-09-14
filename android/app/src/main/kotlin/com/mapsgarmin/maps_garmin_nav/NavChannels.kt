package com.mapsgarmin.maps_garmin_nav

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import com.mapsgarmin.maps_garmin_nav.garmin.ConnectIqBridge
import com.mapsgarmin.maps_garmin_nav.nav.MapsNavListenerService
import com.mapsgarmin.maps_garmin_nav.nav.NavEvent
import com.mapsgarmin.maps_garmin_nav.nav.NavEventBus
import com.mapsgarmin.maps_garmin_nav.nav.WatchDisplaySettings
import com.mapsgarmin.maps_garmin_nav.service.NavForegroundService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

object NavChannels {
    private const val METHODS = "com.mapsgarmin.nav/methods"
    private const val EVENTS = "com.mapsgarmin.nav/events"

    fun register(activity: MainActivity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, METHODS)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStatus" -> result.success(statusMap(activity))
                    "openNotificationListenerSettings" -> {
                        activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }
                    "openBatteryOptimizationSettings" -> {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:${activity.packageName}")
                        }
                        activity.startActivity(intent)
                        result.success(null)
                    }
                    "startForeground" -> {
                        NavForegroundService.start(activity)
                        result.success(null)
                    }
                    "initializeGarmin" -> {
                        ConnectIqBridge.get(activity).ensureInitialized(showUi = true)
                        result.success(null)
                    }
                    "openWatchApp" -> {
                        ConnectIqBridge.get(activity).openWatchApp()
                        result.success(null)
                    }
                    "setTethered" -> {
                        val enabled = call.arguments as? Boolean ?: false
                        ConnectIqBridge.get(activity).setTethered(enabled)
                        result.success(null)
                    }
                    "getWatchDisplaySettings" -> {
                        result.success(WatchDisplaySettings.load(activity).toFlutterMap())
                    }
                    "setWatchDisplaySettings" -> {
                        try {
                            val raw = call.arguments as? Map<*, *>
                            val settings = WatchDisplaySettings.fromFlutterMap(raw)
                            WatchDisplaySettings.save(activity, settings)
                            val bridge = ConnectIqBridge.get(activity)
                            bridge.ensureInitialized(showUi = false)
                            bridge.syncDisplaySettings()
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("SETTINGS", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(engine.dartExecutor.binaryMessenger, EVENTS)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    private var listener: ((NavEvent) -> Unit)? = null

                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        if (events == null) {
                            return
                        }
                        events.success(
                            mapOf("type" to "nav", "payload" to NavEventBus.lastNav.toFlutterMap()),
                        )
                        events.success(
                            mapOf("type" to "garmin", "payload" to NavEventBus.lastGarmin.toMap()),
                        )
                        val callback: (NavEvent) -> Unit = { event ->
                            activity.runOnUiThread {
                                when (event) {
                                    is NavEvent.Nav ->
                                        events.success(
                                            mapOf("type" to "nav", "payload" to event.payload.toFlutterMap()),
                                        )
                                    is NavEvent.Garmin ->
                                        events.success(
                                            mapOf("type" to "garmin", "payload" to event.status.toMap()),
                                        )
                                }
                            }
                        }
                        listener = callback
                        NavEventBus.addListener(callback)
                    }

                    override fun onCancel(arguments: Any?) {
                        listener?.let { NavEventBus.removeListener(it) }
                        listener = null
                    }
                },
            )
    }

    private fun statusMap(context: Context): Map<String, Any?> {
        val garmin = ConnectIqBridge.get(context).currentStatus()
        val nav = NavEventBus.lastNav
        return mapOf(
            "notificationListenerEnabled" to isNotificationListenerEnabled(context),
            "batteryUnrestricted" to isBatteryUnrestricted(context),
            "garmin" to garmin.toMap(),
            "nav" to nav.toFlutterMap(),
        )
    }

    private fun isNotificationListenerEnabled(context: Context): Boolean {
        val component = ComponentName(context, MapsNavListenerService::class.java).flattenToString()
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ).orEmpty()
        return enabled.split(':').any { it.equals(component, ignoreCase = true) }
    }

    private fun isBatteryUnrestricted(context: Context): Boolean {
        val power = context.getSystemService(PowerManager::class.java)
        return power.isIgnoringBatteryOptimizations(context.packageName)
    }
}
