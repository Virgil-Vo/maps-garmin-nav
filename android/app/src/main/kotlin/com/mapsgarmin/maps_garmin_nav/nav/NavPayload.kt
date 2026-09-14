package com.mapsgarmin.maps_garmin_nav.nav

data class NavPayload(
    val status: Int,
    val maneuver: Int,
    val distance: String,
    val road: String,
    val instruction: String,
    val arrivalTime: String = "",
) {
    fun toWatchMap(display: WatchDisplaySettings): HashMap<String, Any> {
        val map =
            hashMapOf<String, Any>(
                "t" to WatchDisplaySettings.MSG_NAV,
                "s" to status,
                "m" to maneuver,
                "d" to NavTextNormalizer.forWatch(distance),
                "r" to NavTextNormalizer.labelForWatch(road),
            )
        if (instruction.isNotBlank()) {
            map["i"] = NavTextNormalizer.labelForWatch(instruction)
        }
        if (display.showArrivalTime && arrivalTime.isNotBlank()) {
            map["a"] = NavTextNormalizer.forWatch(arrivalTime)
        }
        display.putInto(map)
        return map
    }

    fun toFlutterMap(): Map<String, Any> =
        mapOf(
            "s" to status,
            "m" to maneuver,
            "d" to distance,
            "r" to road,
            "i" to instruction,
            "a" to arrivalTime,
        )

    companion object {
        const val STATUS_IDLE = 0
        const val STATUS_NAVIGATING = 1
        const val STATUS_REROUTING = 2
        const val STATUS_ENDED = 3

        val idle = NavPayload(STATUS_IDLE, Maneuver.UNKNOWN, "", "", "", "")
        val ended = NavPayload(STATUS_ENDED, Maneuver.UNKNOWN, "", "", "", "")
    }
}
