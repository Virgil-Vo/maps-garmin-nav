package com.mapsgarmin.maps_garmin_nav.garmin

import android.content.Context
import android.content.pm.PackageManager
import com.garmin.android.connectiq.ConnectIQ
import com.garmin.android.connectiq.IQApp
import com.garmin.android.connectiq.IQDevice
import com.garmin.android.connectiq.exception.InvalidStateException
import com.garmin.android.connectiq.exception.ServiceUnavailableException
import com.mapsgarmin.maps_garmin_nav.WatchAppIds
import com.mapsgarmin.maps_garmin_nav.nav.NavEventBus
import com.mapsgarmin.maps_garmin_nav.nav.NavPayload
import com.mapsgarmin.maps_garmin_nav.nav.WatchDisplaySettings

class ConnectIqBridge private constructor(
    context: Context,
) {
    private val appContext = context.applicationContext
    private var connectIQ: ConnectIQ? = null
    private var device: IQDevice? = null
    private val iqApp = IQApp(WatchAppIds.UUID)
    private var initialized = false
    private var inFlight = false
    private var pending: NavPayload? = null
    private var lastSent: NavPayload? = null
    private var lastSentMap: HashMap<String, Any>? = null
    private var openedForNav = false
    private var tethered = false
    private var pendingConfigSync = false
    private var lastConfigMap: HashMap<String, Any>? = null

    @Synchronized
    fun ensureInitialized(showUi: Boolean) {
        if (initialized) {
            refreshDevices()
            return
        }
        initialize(showUi)
    }

    @Synchronized
    fun setTethered(enabled: Boolean) {
        if (tethered == enabled && initialized) {
            return
        }
        shutdown()
        tethered = enabled
        initialize(showUi = false)
    }

    @Synchronized
    fun send(payload: NavPayload) {
        pending = payload
        flush()
    }

    @Synchronized
    fun syncDisplaySettings() {
        pendingConfigSync = true
        flushConfig()
    }

    @Synchronized
    fun openWatchApp() {
        val sdk = connectIQ ?: return
        val current = device ?: return
        try {
            sdk.openApplication(current, iqApp) { _, _, _ -> }
        } catch (_: Exception) {
            // Watch may be disconnected.
        }
    }

    fun currentStatus(): GarminStatus = NavEventBus.lastGarmin

    private fun initialize(showUi: Boolean) {
        emit(
            GarminStatus(
                garminConnectInstalled = isGarminConnectInstalled(),
                lastError = if (isGarminConnectInstalled()) null else "Garmin Connect is not installed",
            ),
        )
        val type =
            if (tethered) ConnectIQ.IQConnectType.TETHERED else ConnectIQ.IQConnectType.WIRELESS
        val sdk = ConnectIQ.getInstance(appContext, type)
        if (tethered) {
            sdk.setAdbPort(7381)
        }
        connectIQ = sdk
        sdk.initialize(
            appContext,
            showUi,
            object : ConnectIQ.ConnectIQListener {
                override fun onSdkReady() {
                    initialized = true
                    refreshDevices()
                }

                override fun onInitializeError(errStatus: ConnectIQ.IQSdkErrorStatus) {
                    initialized = false
                    emit(
                        GarminStatus(
                            garminConnectInstalled = isGarminConnectInstalled(),
                            lastError = errStatus.name,
                        ),
                    )
                }

                override fun onSdkShutDown() {
                    initialized = false
                    emit(GarminStatus(garminConnectInstalled = isGarminConnectInstalled()))
                }
            },
        )
    }

    private fun refreshDevices() {
        val sdk = connectIQ ?: return
        try {
            val devices = sdk.knownDevices.orEmpty()
            val chosen =
                devices.firstOrNull { it.status == IQDevice.IQDeviceStatus.CONNECTED }
                    ?: devices.firstOrNull()
            device = chosen
            if (chosen != null) {
                chosen.status = sdk.getDeviceStatus(chosen)
                sdk.unregisterForDeviceEvents(chosen)
                sdk.registerForDeviceEvents(chosen) { updated, status ->
                    updated.status = status
                    device = updated
                    queryApp(updated)
                }
                queryApp(chosen)
            } else {
                emit(
                    GarminStatus(
                        sdkReady = true,
                        garminConnectInstalled = isGarminConnectInstalled(),
                        lastError = "No Garmin device found",
                    ),
                )
            }
        } catch (_: InvalidStateException) {
            emit(
                GarminStatus(
                    garminConnectInstalled = isGarminConnectInstalled(),
                    lastError = "Connect IQ is not initialized",
                ),
            )
        } catch (_: ServiceUnavailableException) {
            emit(
                GarminStatus(
                    garminConnectInstalled = isGarminConnectInstalled(),
                    lastError = "Connect IQ service unavailable",
                ),
            )
        }
    }

    private fun queryApp(current: IQDevice) {
        val sdk = connectIQ ?: return
        val connected = current.status == IQDevice.IQDeviceStatus.CONNECTED
        try {
            sdk.getApplicationInfo(
                WatchAppIds.UUID,
                current,
                object : ConnectIQ.IQApplicationInfoListener {
                    override fun onApplicationInfoReceived(app: IQApp) {
                        emit(
                            GarminStatus(
                                sdkReady = true,
                                garminConnectInstalled = true,
                                deviceName = current.friendlyName,
                                deviceConnected = connected,
                                appInstalled = true,
                            ),
                        )
                        flush()
                        syncDisplaySettings()
                    }

                    override fun onApplicationNotInstalled(applicationId: String) {
                        emit(
                            GarminStatus(
                                sdkReady = true,
                                garminConnectInstalled = true,
                                deviceName = current.friendlyName,
                                deviceConnected = connected,
                                appInstalled = false,
                                lastError = "Watch app is not installed",
                            ),
                        )
                    }
                },
            )
        } catch (_: Exception) {
            emit(
                GarminStatus(
                    sdkReady = true,
                    garminConnectInstalled = isGarminConnectInstalled(),
                    deviceName = current.friendlyName,
                    deviceConnected = connected,
                    lastError = "Unable to query watch app",
                ),
            )
        }
    }

    @Synchronized
    private fun flush() {
        val payload = pending ?: return
        if (inFlight) {
            return
        }
        val display = WatchDisplaySettings.load(appContext)
        val map = payload.toWatchMap(display)
        if (mapsEqual(map, lastSentMap)) {
            pending = null
            return
        }
        val sdk = connectIQ ?: return
        val current = device ?: return
        if (current.status != IQDevice.IQDeviceStatus.CONNECTED) {
            emit(currentStatus().copy(deviceConnected = false, lastError = "Watch is not connected"))
            return
        }
        if (payload.status == NavPayload.STATUS_NAVIGATING && !openedForNav) {
            openWatchApp()
            openedForNav = true
        }
        if (payload.status == NavPayload.STATUS_ENDED || payload.status == NavPayload.STATUS_IDLE) {
            openedForNav = false
        }
        pending = null
        sendMap(map, onSuccess = { lastSent = payload })
    }

    @Synchronized
    private fun sendMap(
        map: HashMap<String, Any>,
        onSuccess: (() -> Unit)? = null,
    ) {
        if (inFlight) {
            return
        }
        val sdk = connectIQ ?: return
        val current = device ?: return
        if (current.status != IQDevice.IQDeviceStatus.CONNECTED) {
            emit(currentStatus().copy(deviceConnected = false, lastError = "Watch is not connected"))
            return
        }
        inFlight = true
        try {
            sdk.sendMessage(current, iqApp, map) { _, _, status ->
                synchronized(this) {
                    inFlight = false
                    if (status == ConnectIQ.IQMessageStatus.SUCCESS) {
                        lastSentMap = HashMap(map)
                        if (map["t"] == WatchDisplaySettings.MSG_CONFIG) {
                            lastConfigMap = HashMap(map)
                            pendingConfigSync = false
                        }
                        onSuccess?.invoke()
                    } else {
                        emit(currentStatus().copy(lastError = status.name))
                    }
                    flush()
                    flushConfig()
                }
            }
        } catch (error: Exception) {
            inFlight = false
            emit(currentStatus().copy(lastError = error.message))
        }
    }

    @Synchronized
    private fun flushConfig() {
        if (!pendingConfigSync || inFlight) {
            return
        }
        val map = WatchDisplaySettings.load(appContext).toConfigMap()
        if (mapsEqual(map, lastConfigMap)) {
            pendingConfigSync = false
            return
        }
        val sdk = connectIQ ?: return
        val current = device ?: return
        if (current.status != IQDevice.IQDeviceStatus.CONNECTED) {
            return
        }
        sendMap(map)
    }

    private fun mapsEqual(a: HashMap<String, Any>?, b: HashMap<String, Any>?): Boolean {
        if (a == null || b == null) {
            return a == b
        }
        if (a.size != b.size) {
            return false
        }
        return a.entries.all { entry -> b[entry.key] == entry.value }
    }

    private fun shutdown() {
        try {
            connectIQ?.unregisterAllForEvents()
            connectIQ?.shutdown(appContext)
        } catch (_: Exception) {
            // Already shut down.
        }
        initialized = false
        inFlight = false
        device = null
        connectIQ = null
    }

    private fun isGarminConnectInstalled(): Boolean {
        return try {
            appContext.packageManager.getPackageInfo(WatchAppIds.GCM_PACKAGE, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun emit(status: GarminStatus) {
        NavEventBus.emitGarmin(status)
    }

    companion object {
        @Volatile
        private var instance: ConnectIqBridge? = null

        fun get(context: Context): ConnectIqBridge {
            return instance ?: synchronized(this) {
                instance ?: ConnectIqBridge(context).also { instance = it }
            }
        }
    }
}
