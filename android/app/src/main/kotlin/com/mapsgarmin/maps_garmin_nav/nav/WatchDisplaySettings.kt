package com.mapsgarmin.maps_garmin_nav.nav

import android.content.Context

data class WatchDisplaySettings(
    val showManeuverIcon: Boolean = true,
    val showDistance: Boolean = true,
    val showStreetName: Boolean = true,
    val showArrivalTime: Boolean = false,
    val textScale: Int = SCALE_NORMAL,
    val iconScale: Int = SCALE_NORMAL,
) {
    fun putInto(map: HashMap<String, Any>) {
        map["sd"] = if (showDistance) 1 else 0
        map["sl"] = if (showStreetName) 1 else 0
        map["si"] = if (showManeuverIcon) 1 else 0
        map["sa"] = if (showArrivalTime) 1 else 0
        map["ts"] = textScale.coerceIn(SCALE_COMPACT, SCALE_LARGE)
        map["is"] = iconScale.coerceIn(SCALE_COMPACT, SCALE_LARGE)
    }

    fun toConfigMap(): HashMap<String, Any> {
        val map = hashMapOf<String, Any>("t" to MSG_CONFIG)
        putInto(map)
        return map
    }

    fun toFlutterMap(): Map<String, Any> =
        mapOf(
            "showManeuverIcon" to showManeuverIcon,
            "showDistance" to showDistance,
            "showStreetName" to showStreetName,
            "showArrivalTime" to showArrivalTime,
            "textScale" to textScale,
            "iconScale" to iconScale,
        )

    companion object {
        const val MSG_NAV = "n"
        const val MSG_CONFIG = "c"

        const val SCALE_COMPACT = 0
        const val SCALE_NORMAL = 1
        const val SCALE_LARGE = 2

        private const val PREFS = "watch_display_settings"

        fun load(context: Context): WatchDisplaySettings {
            val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return WatchDisplaySettings(
                showManeuverIcon = prefs.getBoolean("showManeuverIcon", true),
                showDistance = prefs.getBoolean("showDistance", true),
                showStreetName = prefs.getBoolean("showStreetName", true),
                showArrivalTime = prefs.getBoolean("showArrivalTime", false),
                textScale = prefs.getInt("textScale", SCALE_NORMAL),
                iconScale = prefs.getInt("iconScale", SCALE_NORMAL),
            )
        }

        fun save(context: Context, settings: WatchDisplaySettings) {
            context.applicationContext
                .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putBoolean("showManeuverIcon", settings.showManeuverIcon)
                .putBoolean("showDistance", settings.showDistance)
                .putBoolean("showStreetName", settings.showStreetName)
                .putBoolean("showArrivalTime", settings.showArrivalTime)
                .putInt("textScale", settings.textScale.coerceIn(SCALE_COMPACT, SCALE_LARGE))
                .putInt("iconScale", settings.iconScale.coerceIn(SCALE_COMPACT, SCALE_LARGE))
                .apply()
        }

        fun fromFlutterMap(map: Map<*, *>?): WatchDisplaySettings {
            if (map == null) {
                return WatchDisplaySettings()
            }
            return WatchDisplaySettings(
                showManeuverIcon = readBool(map, "showManeuverIcon", true),
                showDistance = readBool(map, "showDistance", true),
                showStreetName = readBool(map, "showStreetName", true),
                showArrivalTime = readBool(map, "showArrivalTime", false),
                textScale = (map["textScale"] as? Number)?.toInt() ?: SCALE_NORMAL,
                iconScale = (map["iconScale"] as? Number)?.toInt() ?: SCALE_NORMAL,
            )
        }

        private fun readBool(map: Map<*, *>, key: String, default: Boolean): Boolean {
            val value = map[key] ?: return default
            return when (value) {
                is Boolean -> value
                is Number -> value.toInt() != 0
                else -> default
            }
        }
    }
}
