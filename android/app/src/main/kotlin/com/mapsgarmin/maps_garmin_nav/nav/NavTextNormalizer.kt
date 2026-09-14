package com.mapsgarmin.maps_garmin_nav.nav

import java.text.Normalizer

object NavTextNormalizer {
    private val arrivalTimePattern =
        Regex("""(?i)arrive\s+\d{1,2}:\d{2}\s*(?:am|pm)?""")
    /**
     * Garmin system fonts on Forerunner often lack Vietnamese glyphs.
     * Send unaccented ASCII so road names stay readable on the watch.
     */
    fun forWatch(text: String): String {
        if (text.isBlank()) {
            return text
        }
        return stripDiacritics(text)
            .replace(Regex("""[^\x00-\x7F]"""), "")
            .replace(Regex("""\s+"""), " ")
            .trim()
    }

    fun extractArrivalTime(vararg parts: String): String {
        for (part in parts) {
            val match = arrivalTimePattern.find(part.trim())
            if (match != null) {
                return match.value.trim()
            }
        }
        return ""
    }

    fun withoutArrivalTime(text: String): String {
        if (text.isBlank()) {
            return text
        }
        return text
            .replace(arrivalTimePattern, " ")
            .replace(Regex("""\s+"""), " ")
            .trim()
    }

    /** Removes ETA / "Arrive" clutter Maps often mixes into street lines. */
    fun labelForWatch(text: String): String {
        if (text.isBlank()) {
            return text
        }
        var cleaned = text
        cleaned = withoutArrivalTime(cleaned)
        cleaned = cleaned.replace(Regex("(?i)\\barrive\\b"), " ")
        cleaned = cleaned.replace(Regex("""\s+"""), " ").trim()
        return forWatch(cleaned)
    }

    /** Lowercase text with Vietnamese diacritics removed (for keyword matching). */
    fun foldForMatching(text: String): String {
        return stripDiacritics(text).lowercase()
    }

    private fun stripDiacritics(text: String): String {
        val decomposed = Normalizer.normalize(text, Normalizer.Form.NFD)
        return decomposed
            .replace(Regex("\\p{Mn}+"), "")
            .replace('đ', 'd')
            .replace('Đ', 'D')
    }
}
