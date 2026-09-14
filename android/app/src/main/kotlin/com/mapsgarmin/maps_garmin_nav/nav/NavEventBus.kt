package com.mapsgarmin.maps_garmin_nav.nav

import com.mapsgarmin.maps_garmin_nav.garmin.GarminStatus
import java.util.concurrent.CopyOnWriteArraySet

sealed class NavEvent {
    data class Nav(val payload: NavPayload) : NavEvent()
    data class Garmin(val status: GarminStatus) : NavEvent()
}

object NavEventBus {
    private val listeners = CopyOnWriteArraySet<(NavEvent) -> Unit>()

    @Volatile
    var lastNav: NavPayload = NavPayload.idle
        private set

    @Volatile
    var lastGarmin: GarminStatus = GarminStatus()
        private set

    fun addListener(listener: (NavEvent) -> Unit) {
        listeners.add(listener)
    }

    fun removeListener(listener: (NavEvent) -> Unit) {
        listeners.remove(listener)
    }

    fun emitNav(payload: NavPayload) {
        lastNav = payload
        listeners.forEach { it(NavEvent.Nav(payload)) }
    }

    fun emitGarmin(status: GarminStatus) {
        lastGarmin = status
        listeners.forEach { it(NavEvent.Garmin(status)) }
    }
}
