package com.mapsgarmin.maps_garmin_nav.nav

data class NavPayload(
    val status: Int,
    val maneuver: Int,
    val distance: String,
    val road: String,
    val instruction: String,
) {
    fun toWatchMap(): HashMap<String, Any> {
        val map = hashMapOf<String, Any>(
            "s" to status,
            "m" to maneuver,
            "d" to distance,
            "r" to road,
        )
        if (instruction.isNotBlank() && instruction != road) {
            map["i"] = instruction
        }
        return map
    }

    fun toFlutterMap(): Map<String, Any> =
        mapOf(
            "s" to status,
            "m" to maneuver,
            "d" to distance,
            "r" to road,
            "i" to instruction,
        )

    companion object {
        const val STATUS_IDLE = 0
        const val STATUS_NAVIGATING = 1
        const val STATUS_REROUTING = 2
        const val STATUS_ENDED = 3

        val idle = NavPayload(STATUS_IDLE, Maneuver.UNKNOWN, "", "", "")
        val ended = NavPayload(STATUS_ENDED, Maneuver.UNKNOWN, "", "", "")
    }
}
