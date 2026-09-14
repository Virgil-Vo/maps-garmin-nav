package com.mapsgarmin.maps_garmin_nav.garmin

data class GarminStatus(
    val sdkReady: Boolean = false,
    val garminConnectInstalled: Boolean = false,
    val deviceName: String? = null,
    val deviceConnected: Boolean = false,
    val appInstalled: Boolean = false,
    val lastError: String? = null,
) {
    fun toMap(): Map<String, Any?> =
        mapOf(
            "sdkReady" to sdkReady,
            "garminConnectInstalled" to garminConnectInstalled,
            "deviceName" to deviceName,
            "deviceConnected" to deviceConnected,
            "appInstalled" to appInstalled,
            "lastError" to lastError,
        )
}
