package com.mapsgarmin.maps_garmin_nav.nav

import android.os.Bundle
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

object MapsNotificationLogger {
    private const val TAG = "MapsGarminNav"
    private const val MAX_LOG_CHUNK = 3500

    fun log(
        sbn: StatusBarNotification,
        remoteViewTexts: Map<String, String>,
        parsed: NavPayload?,
    ) {
        val root =
            JSONObject().apply {
                put("package", sbn.packageName)
                put("id", sbn.id)
                put("tag", sbn.tag)
                put("postTime", sbn.postTime)
                put("isOngoing", sbn.isOngoing)
                put("notification", notificationJson(sbn.notification))
                put("remoteViewTexts", JSONObject(remoteViewTexts))
                put(
                    "parsedPayload",
                    if (parsed == null) {
                        JSONObject.NULL
                    } else {
                        JSONObject(parsed.toFlutterMap())
                    },
                )
            }
        logJson(root.toString(2))
    }

    private fun notificationJson(notification: android.app.Notification): JSONObject {
        return JSONObject().apply {
            put("category", notification.category)
            put("flags", notification.flags)
            put("extras", bundleToJson(notification.extras))
        }
    }

    private fun bundleToJson(bundle: Bundle): JSONObject {
        val json = JSONObject()
        for (key in bundle.keySet()) {
            json.put(key, valueToJson(bundle.get(key)))
        }
        return json
    }

    private fun valueToJson(value: Any?): Any {
        return when (value) {
            null -> JSONObject.NULL
            is String -> value
            is Int, is Long, is Boolean, is Double, is Float -> value
            is CharSequence -> value.toString()
            is Bundle -> bundleToJson(value)
            is IntArray -> JSONArray(value.toList())
            is LongArray -> JSONArray(value.toList())
            is BooleanArray -> JSONArray(value.toList())
            is DoubleArray -> JSONArray(value.toList())
            is FloatArray -> JSONArray(value.toList())
            is Array<*> -> JSONArray(value.map { valueToJson(it) })
            is ArrayList<*> -> JSONArray(value.map { valueToJson(it) })
            else -> value.toString()
        }
    }

    private fun logJson(json: String) {
        if (json.length <= MAX_LOG_CHUNK) {
            Log.i(TAG, "Maps notification JSON:\n$json")
            return
        }
        var offset = 0
        var part = 1
        while (offset < json.length) {
            val end = minOf(offset + MAX_LOG_CHUNK, json.length)
            Log.i(TAG, "Maps notification JSON ($part):\n${json.substring(offset, end)}")
            offset = end
            part += 1
        }
    }
}
