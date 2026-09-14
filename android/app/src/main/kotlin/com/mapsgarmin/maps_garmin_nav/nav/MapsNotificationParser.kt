package com.mapsgarmin.maps_garmin_nav.nav

import android.app.Notification
import android.content.Context
import android.os.Build
import android.service.notification.StatusBarNotification
import android.view.LayoutInflater
import android.view.ViewGroup
import android.widget.RemoteViews
import android.widget.TextView
import com.mapsgarmin.maps_garmin_nav.WatchAppIds

class MapsNotificationParser(
    private val context: Context,
) {
    fun parse(sbn: StatusBarNotification): NavPayload? {
        if (!isMapsNavigation(sbn)) {
            return null
        }

        val extras = sbn.notification.extras
        var distance = firstNonBlank(
            extras.getCharSequence(Notification.EXTRA_TITLE)?.toString(),
            extras.getCharSequence(Notification.EXTRA_TITLE_BIG)?.toString(),
        )
        var description = firstNonBlank(
            extras.getCharSequence(Notification.EXTRA_TEXT)?.toString(),
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString(),
            extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString(),
            extras.getCharSequence(Notification.EXTRA_INFO_TEXT)?.toString(),
        )

        try {
            val remote = parseRemoteViews(sbn.notification)
            if (remote.distance.isNotBlank()) {
                distance = remote.distance
            }
            if (remote.description.isNotBlank()) {
                description = remote.description
            }
        } catch (_: Exception) {
            // Maps layouts change; extras remain the fallback.
        }

        val combined = listOf(distance, description).filter { it.isNotBlank() }
        if (combined.any { ManeuverClassifier.isRerouting(it) }) {
            return NavPayload(
                status = NavPayload.STATUS_REROUTING,
                maneuver = Maneuver.UNKNOWN,
                distance = "",
                road = "",
                instruction = "Rerouting",
            )
        }

        val (resolvedDistance, instruction) = resolveDistanceAndInstruction(distance, description)
        if (instruction.isBlank() && resolvedDistance.isBlank()) {
            return null
        }

        val (turn, road) = ManeuverClassifier.splitInstruction(instruction)
        return NavPayload(
            status = NavPayload.STATUS_NAVIGATING,
            maneuver = ManeuverClassifier.classify(instruction),
            distance = resolvedDistance,
            road = road.ifBlank { instruction },
            instruction = turn.ifBlank { instruction },
        )
    }

    private fun isMapsNavigation(sbn: StatusBarNotification): Boolean {
        if (WatchAppIds.MAPS_PACKAGE !in sbn.packageName) {
            return false
        }
        if (!sbn.isOngoing) {
            return false
        }
        return sbn.id == 1 || sbn.notification.flags and Notification.FLAG_ONGOING_EVENT != 0
    }

    private fun resolveDistanceAndInstruction(
        first: String,
        second: String,
    ): Pair<String, String> {
        val a = first.trim()
        val b = second.trim()
        return when {
            ManeuverClassifier.looksLikeDistance(a) -> a to b
            ManeuverClassifier.looksLikeDistance(b) -> b to a
            else -> {
                val parts = "$a $b".split("·", "•", "-", "|").map { it.trim() }
                val dist = parts.firstOrNull { ManeuverClassifier.looksLikeDistance(it) }.orEmpty()
                val rest = parts.filterNot { it == dist || it.isEmpty() }.joinToString(" ")
                dist to rest.ifBlank { b.ifBlank { a } }
            }
        }
    }

    private data class RemoteParsed(
        val distance: String = "",
        val description: String = "",
    )

    private fun parseRemoteViews(notification: Notification): RemoteParsed {
        val mapsContext =
            context.createPackageContext(WatchAppIds.MAPS_PACKAGE, Context.CONTEXT_IGNORE_SECURITY)
        val remoteViews = contentView(notification) ?: return RemoteParsed()
        val inflater = mapsContext.getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        val group = inflater.inflate(remoteViews.layoutId, null) as? ViewGroup ?: return RemoteParsed()
        remoteViews.reapply(mapsContext, group)
        val texts = linkedMapOf<String, String>()
        collectTexts(group, mapsContext, texts)
        val distance = firstNonBlank(
            texts["nav_title"],
            texts.values.firstOrNull { ManeuverClassifier.looksLikeDistance(it) },
        )
        val description = firstNonBlank(
            texts["nav_description"],
            texts["lockscreen_directions"],
            texts["lockscreen_oneliner"],
            texts["title"]?.takeIf { !ManeuverClassifier.looksLikeDistance(it) },
            texts["text"]?.takeIf { !ManeuverClassifier.looksLikeDistance(it) },
        )
        return RemoteParsed(distance = distance, description = description)
    }

    private fun contentView(notification: Notification): RemoteViews? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val builder = Notification.Builder.recoverBuilder(context, notification)
            return builder.createBigContentView() ?: builder.createContentView()
        }
        @Suppress("DEPRECATION")
        return notification.bigContentView ?: notification.contentView
    }

    private fun collectTexts(
        group: ViewGroup,
        mapsContext: Context,
        out: MutableMap<String, String>,
    ) {
        for (index in 0 until group.childCount) {
            when (val child = group.getChildAt(index)) {
                is TextView -> {
                    val name = resourceName(mapsContext, child.id)
                    val value = child.text?.toString()?.trim().orEmpty()
                    if (name.isNotBlank() && value.isNotBlank()) {
                        out[name] = value
                    }
                }
                is ViewGroup -> collectTexts(child, mapsContext, out)
            }
        }
    }

    private fun resourceName(mapsContext: Context, id: Int): String {
        if (id <= 0) {
            return ""
        }
        return try {
            mapsContext.resources.getResourceEntryName(id)
        } catch (_: Exception) {
            ""
        }
    }

    private fun firstNonBlank(vararg values: String?): String =
        values.firstOrNull { !it.isNullOrBlank() }?.trim().orEmpty()
}
