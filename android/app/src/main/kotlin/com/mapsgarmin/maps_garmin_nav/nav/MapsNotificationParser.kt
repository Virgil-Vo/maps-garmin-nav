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
        var remoteTexts = emptyMap<String, String>()
        try {
            remoteTexts = parseRemoteViews(sbn.notification).texts
        } catch (_: Exception) {
            // Maps layouts change; extras remain the fallback.
        }

        val titleLine =
            firstNonBlank(
                extras.getCharSequence(Notification.EXTRA_TITLE)?.toString(),
                extras.getCharSequence(Notification.EXTRA_TITLE_BIG)?.toString(),
                remoteTexts["alt_title"],
                remoteTexts["nav_title"],
            )
        val extraTextLine =
            firstNonBlank(
                extras.getCharSequence(Notification.EXTRA_TEXT)?.toString(),
                extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString(),
                extras.getCharSequence(Notification.EXTRA_INFO_TEXT)?.toString(),
                remoteTexts["alt_text"],
                remoteTexts["nav_text"],
            )
        val shortDistance =
            firstNonBlank(
                extras.getCharSequence("android.shortCriticalText")?.toString(),
                remoteTexts["short_critical_text"],
            )
        val etaLine =
            firstNonBlank(
                extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString(),
                remoteTexts["alt_subtext"],
                remoteTexts["nav_subtext"],
            )

        val combined = listOf(titleLine, etaLine).filter { it.isNotBlank() }
        if (combined.any { ManeuverClassifier.isRerouting(it) }) {
            val payload =
                NavPayload(
                    status = NavPayload.STATUS_REROUTING,
                    maneuver = Maneuver.UNKNOWN,
                    distance = "",
                    road = "",
                    instruction = "Rerouting",
                )
            MapsNotificationLogger.log(sbn, remoteTexts, payload)
            return payload
        }

        val peeled = ManeuverClassifier.peelDistanceAndRest(titleLine)
        val peeledExtra = ManeuverClassifier.peelDistanceAndRest(extraTextLine)
        val distance =
            when {
                shortDistance.isNotBlank() &&
                    ManeuverClassifier.looksLikeDistance(shortDistance) ->
                    shortDistance
                peeled.first.isNotBlank() -> peeled.first
                peeledExtra.first.isNotBlank() -> peeledExtra.first
                else -> ""
            }
        val maneuverLine =
            NavTextNormalizer.withoutArrivalTime(
                peeled.second.ifBlank { titleLine }.ifBlank { extraTextLine },
            )
        if (maneuverLine.isBlank() && distance.isBlank()) {
            MapsNotificationLogger.log(sbn, remoteTexts, null)
            return null
        }

        val arrivalTime = NavTextNormalizer.extractArrivalTime(etaLine, titleLine, maneuverLine)
        val (turn, roadPart) = ManeuverClassifier.splitInstruction(maneuverLine)
        val maneuverSource =
            turn.ifBlank { ManeuverClassifier.sanitizeForManeuver(maneuverLine) }
        val turnText = NavTextNormalizer.withoutArrivalTime(turn.ifBlank { maneuverLine })
        val street =
            ManeuverClassifier.targetStreet(
                NavTextNormalizer.withoutArrivalTime(roadPart.ifBlank { maneuverLine }),
                maneuverLine,
            )
        val classifyText = maneuverSource.ifBlank { maneuverLine }
        val payload =
            NavPayload(
                status = NavPayload.STATUS_NAVIGATING,
                maneuver = ManeuverClassifier.classify(classifyText),
                distance = distance,
                road = street,
                instruction = turnText,
                arrivalTime = arrivalTime,
            )
        MapsNotificationLogger.log(sbn, remoteTexts, payload)
        return payload
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

    private data class RemoteParsed(
        val texts: Map<String, String> = emptyMap(),
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
        return RemoteParsed(texts = texts)
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
