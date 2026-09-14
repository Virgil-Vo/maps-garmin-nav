package com.mapsgarmin.maps_garmin_nav.nav

object Maneuver {
    const val UNKNOWN = 0
    const val CONTINUE = 1
    const val LEFT = 2
    const val RIGHT = 3
    const val SLIGHT_LEFT = 4
    const val SLIGHT_RIGHT = 5
    const val SHARP_LEFT = 6
    const val SHARP_RIGHT = 7
    const val U_TURN = 8
    const val ROUNDABOUT = 9
    const val MERGE = 10
    const val ARRIVE = 11
    const val DEPART = 12
    const val KEEP_LEFT = 13
    const val KEEP_RIGHT = 14
}

object ManeuverClassifier {
    private val ontoPattern =
        Regex("""(?i)(?:onto|on|toward|towards|to stay on)\s+(.+)$""")

    fun classify(instruction: String): Int {
        val text = instruction.lowercase()
        return when {
            text.contains("u-turn") || text.contains("u turn") || text.contains("make a uturn") ->
                Maneuver.U_TURN
            text.contains("roundabout") || text.contains("rotary") || text.contains("traffic circle") ->
                Maneuver.ROUNDABOUT
            text.contains("arrive") || text.contains("destination") || text.contains("you have reached") ->
                Maneuver.ARRIVE
            text.contains("depart") || text.contains("head ") ->
                Maneuver.DEPART
            text.contains("merge") ->
                Maneuver.MERGE
            text.contains("keep left") || text.contains("stay left") ->
                Maneuver.KEEP_LEFT
            text.contains("keep right") || text.contains("stay right") ->
                Maneuver.KEEP_RIGHT
            text.contains("sharp left") || text.contains("turn hard left") ->
                Maneuver.SHARP_LEFT
            text.contains("sharp right") || text.contains("turn hard right") ->
                Maneuver.SHARP_RIGHT
            text.contains("slight left") || text.contains("bear left") ->
                Maneuver.SLIGHT_LEFT
            text.contains("slight right") || text.contains("bear right") ->
                Maneuver.SLIGHT_RIGHT
            text.contains("turn left") || text.contains("left turn") || text.startsWith("left ") ->
                Maneuver.LEFT
            text.contains("turn right") || text.contains("right turn") || text.startsWith("right ") ->
                Maneuver.RIGHT
            text.contains("continue") || text.contains("straight") || text.contains("proceed") ->
                Maneuver.CONTINUE
            else -> Maneuver.UNKNOWN
        }
    }

    fun splitInstruction(instruction: String): Pair<String, String> {
        val trimmed = instruction.trim()
        if (trimmed.isEmpty()) {
            return "" to ""
        }
        val match = ontoPattern.find(trimmed)
        if (match != null) {
            val road = match.groupValues[1].trim()
            val turn = trimmed.substring(0, match.range.first).trim().trimEnd(',', '.', '-')
            if (road.isNotEmpty() && turn.isNotEmpty()) {
                return turn to road
            }
        }
        return trimmed to trimmed
    }

    fun looksLikeDistance(value: String): Boolean =
        DISTANCE.matches(value.trim())

    fun isRerouting(value: String): Boolean {
        val text = value.lowercase()
        return text.contains("rerout") || text.contains("recalculat")
    }

    private val DISTANCE =
        Regex("""^[\d.,]+\s*(km|mi|m|ft|yd|公尺|千米|米)\.?$""", RegexOption.IGNORE_CASE)
}
