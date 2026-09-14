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
    const val ROUNDABOUT_STRAIGHT = 15
    const val ROUNDABOUT_LEFT = 16
    const val ROUNDABOUT_RIGHT = 17
}

object ManeuverClassifier {
    // Word "on" alone must not match "(on the left)" — use onto / toward / Vietnamese only.
    private val ontoWordPattern =
        Regex("""(?i)\b(?:onto|toward|towards)\s+""")
    private val ontoVietnamesePattern =
        Regex("""(?i)\b(?:vào|vao|sang|trên|tren|tới|toi|đi vào|di vao)\s+""")
    private val stayOnPattern =
        Regex("""(?i)\bto stay on\s+""")

    private val etaArrivePattern =
        Regex("""(?i)arrive\s+\d{1,2}:\d{2}\s*(?:am|pm)?""")

    fun sanitizeForManeuver(instruction: String): String {
        var cleaned = instruction.trim()
        cleaned = cleaned.replace(etaArrivePattern, " ")
        cleaned = cleaned.replace(Regex("""[·•|]"""), " ")
        cleaned = cleaned.replace(Regex("""\s+"""), " ").trim()
        return cleaned
    }

    fun classify(instruction: String): Int {
        val text = NavTextNormalizer.foldForMatching(sanitizeForManeuver(instruction))
        return when {
            containsAny(text, "u-turn", "u turn", "make a uturn", "quay dau", "quay đầu") ->
                Maneuver.U_TURN
            containsAny(
                text,
                "roundabout",
                "rotary",
                "traffic circle",
                "vong quay",
                "vòng quay",
                "vong xuyen",
                "vòng xuyến",
            ) -> refineRoundaboutManeuver(text)
            isDestinationArrival(text) -> Maneuver.ARRIVE
            containsAny(text, "depart", "bat dau", "bắt đầu", "khoi hanh", "khởi hành")
                || Regex("""\bhead\s""").containsMatchIn(text) ->
                Maneuver.DEPART
            containsAny(text, "merge", "nhap lan", "nhập làn", "gop lan", "gộp làn") ->
                Maneuver.MERGE
            containsAny(
                text,
                "keep left",
                "stay left",
                "giu ben trai",
                "giữ bên trái",
                "bam trai",
                "bám trái",
                "di ve ben trai",
                "đi về bên trái",
            ) -> Maneuver.KEEP_LEFT
            containsAny(
                text,
                "keep right",
                "stay right",
                "giu ben phai",
                "giữ bên phải",
                "bam phai",
                "bám phải",
                "di ve ben phai",
                "đi về bên phải",
            ) -> Maneuver.KEEP_RIGHT
            containsAny(text, "sharp left", "turn hard left", "re gap sang trai", "rẽ gấp sang trái") ->
                Maneuver.SHARP_LEFT
            containsAny(text, "sharp right", "turn hard right", "re gap sang phai", "rẽ gấp sang phải") ->
                Maneuver.SHARP_RIGHT
            containsAny(
                text,
                "slight left",
                "bear left",
                "re nhe sang trai",
                "rẽ nhẹ sang trái",
                "hoi sang trai",
                "hơi sang trái",
            ) -> Maneuver.SLIGHT_LEFT
            containsAny(
                text,
                "slight right",
                "bear right",
                "re nhe sang phai",
                "rẽ nhẹ sang phải",
                "hoi sang phai",
                "hơi sang phải",
            ) -> Maneuver.SLIGHT_RIGHT
            containsAny(
                text,
                "turn left",
                "left turn",
                "re trai",
                "rẽ trái",
                "queo trai",
                "quẹo trái",
                "re ve phia trai",
                "rẽ về phía trái",
            ) || text.startsWith("left ") || text.startsWith("re trai") ->
                Maneuver.LEFT
            containsAny(
                text,
                "turn right",
                "right turn",
                "re phai",
                "rẽ phải",
                "queo phai",
                "quẹo phải",
                "re ve phia phai",
                "rẽ về phía phải",
            ) || text.startsWith("right ") || text.startsWith("re phai") ->
                Maneuver.RIGHT
            containsAny(
                text,
                "continue",
                "straight",
                "proceed",
                "di thang",
                "đi thẳng",
                "tiep tuc",
                "tiếp tục",
                "theo duong",
                "theo đường",
            ) -> Maneuver.CONTINUE
            else -> Maneuver.UNKNOWN
        }
    }

    private val combinedDistanceLine =
        Regex(
            """^([\d.,]+\s*(?:km|m|mi|ft|yd|mét|met|kilômét|kilomet)\.?)\s*(?:[·•|\-–]\s*)(.+)$""",
            RegexOption.IGNORE_CASE,
        )

    /** Splits `160 m · Turn left…` into distance and the rest. */
    fun peelDistanceAndRest(line: String): Pair<String, String> {
        val trimmed = normalizeBulletSeparators(line.trim())
        if (trimmed.isEmpty()) {
            return "" to ""
        }
        combinedDistanceLine.find(trimmed)?.let { match ->
            return match.groupValues[1].trim() to match.groupValues[2].trim()
        }
        if (DISTANCE_STRICT.matches(trimmed)) {
            return trimmed to ""
        }
        val prefix = DISTANCE_PREFIX.find(trimmed)
        if (prefix != null) {
            val distance = prefix.value.trim()
            val tail = trimmed.substring(prefix.range.last + 1).trim()
            if (tail.isEmpty()) {
                return distance to ""
            }
            val separators = listOf("·", "•", "|", "–", "-")
            if (separators.any { tail.startsWith(it) }) {
                return distance to tail.drop(1).trim()
            }
            if (!DISTANCE_STRICT.matches(trimmed)) {
                return distance to tail
            }
        }
        return "" to trimmed
    }

    private fun normalizeBulletSeparators(line: String): String {
        return line
            .replace('\u00B7', '·')
            .replace('\u2022', '·')
            .replace('\u2219', '·')
            .replace('\u30FB', '·')
            .replace(Regex("""\s*/\s*"""), " · ")
    }

    fun targetStreet(road: String, instruction: String): String {
        val trimmedRoad = road.trim()
        val trimmedInstruction = instruction.trim()
        val fromInstruction = streetAfterOnto(trimmedInstruction)
        if (fromInstruction.isNotEmpty()) {
            return fromInstruction
        }
        if (trimmedRoad.isNotEmpty() && !trimmedRoad.equals(trimmedInstruction, ignoreCase = true)) {
            return trimmedRoad
        }
        return trimmedRoad
    }

    fun splitInstruction(instruction: String): Pair<String, String> {
        val trimmed = instruction.trim()
        if (trimmed.isEmpty()) {
            return "" to ""
        }
        val match = lastOntoMatch(trimmed) ?: return trimmed to trimmed
        val street = trimmed.substring(match.range.last + 1).trim()
        val turn =
            trimmed
                .substring(0, match.range.first)
                .trim()
                .trimEnd(',', '.', '-', '–')
        if (street.isNotEmpty() && turn.isNotEmpty()) {
            return turn to street
        }
        return trimmed to street
    }

    private fun streetAfterOnto(instruction: String): String {
        val trimmed = instruction.trim()
        val match = lastOntoMatch(trimmed) ?: return ""
        return trimmed.substring(match.range.last + 1).trim()
    }

    private fun lastOntoMatch(text: String): MatchResult? {
        return listOf(ontoWordPattern, ontoVietnamesePattern, stayOnPattern)
            .flatMap { pattern -> pattern.findAll(text).toList() }
            .maxByOrNull { it.range.first }
    }

    fun looksLikeDistance(value: String): Boolean {
        val (distance, rest) = peelDistanceAndRest(value.trim())
        return distance.isNotEmpty() && rest.isEmpty()
    }

    fun isRerouting(value: String): Boolean {
        val text = NavTextNormalizer.foldForMatching(value)
        return containsAny(
            text,
            "rerout",
            "recalculat",
            "tinh lai",
            "tính lại",
            "dinh tuyen",
            "định tuyến",
            "tim duong",
            "tìm đường",
        )
    }

    private fun isDestinationArrival(text: String): Boolean {
        if (etaArrivePattern.containsMatchIn(text)) {
            return false
        }
        return containsAny(
            text,
            "destination",
            "you have reached",
            "den dich",
            "đến đích",
            "da den",
            "đã đến",
            "diem den",
            "điểm đến",
            "den noi",
            "đến nơi",
        ) || (text.contains("arrive") && !text.contains("turn") && !text.contains("onto"))
    }

    private fun containsAny(haystack: String, vararg needles: String): Boolean =
        needles.any { haystack.contains(NavTextNormalizer.foldForMatching(it)) }

    /**
     * Maps roundabout phrases: "turn left/right", "continue straight", "take the Nth exit".
     * Exit numbers use right-hand traffic (Vietnam): 1st ≈ right, 2nd ≈ straight, 3rd ≈ left.
     * Unknown exit stays ROUNDABOUT (9), never assumed straight.
     */
    fun refineRoundaboutManeuver(text: String): Int {
        val result =
            when {
                ROUNDABOUT_LEFT_PHRASE.containsMatchIn(text) -> Maneuver.ROUNDABOUT_LEFT
                ROUNDABOUT_RIGHT_PHRASE.containsMatchIn(text) -> Maneuver.ROUNDABOUT_RIGHT
                else -> {
                    val ordinal = roundaboutExitOrdinal(text)
                    when (ordinal) {
                        1 -> Maneuver.ROUNDABOUT_RIGHT
                        2 -> Maneuver.ROUNDABOUT_STRAIGHT
                        3 -> Maneuver.ROUNDABOUT_LEFT
                        4 -> Maneuver.U_TURN
                        else ->
                            when {
                                ROUNDABOUT_STRAIGHT_PHRASE.containsMatchIn(text) ->
                                    Maneuver.ROUNDABOUT_STRAIGHT
                                Regex("""\bleft\b""").containsMatchIn(text) ->
                                    Maneuver.ROUNDABOUT_LEFT
                                Regex("""\bright\b""").containsMatchIn(text) ->
                                    Maneuver.ROUNDABOUT_RIGHT
                                else -> Maneuver.ROUNDABOUT_STRAIGHT
                            }
                    }
                }
            }
        return result
    }

    private fun roundaboutExitOrdinal(text: String): Int? {
        val match = ROUNDABOUT_EXIT_ORDINAL.find(text) ?: return null
        val raw = match.groupValues[1]
        return when (raw) {
            "1", "1st", "first" -> 1
            "2", "2nd", "second" -> 2
            "3", "3rd", "third" -> 3
            "4", "4th", "fourth" -> 4
            else -> raw.toIntOrNull()
        }
    }

    private val ROUNDABOUT_LEFT_PHRASE =
        Regex(
            """\b(?:turn\s+left|left\s+turn|bear\s+left|exit\s+left|take\s+the\s+left|re\s*trai|queo\s*trai)\b""",
        )
    private val ROUNDABOUT_RIGHT_PHRASE =
        Regex(
            """\b(?:turn\s+right|right\s+turn|bear\s+right|exit\s+right|take\s+the\s+right|re\s*phai|queo\s*phai)\b""",
        )
    private val ROUNDABOUT_STRAIGHT_PHRASE =
        Regex(
            """\b(?:continue|straight|proceed|go\s+straight|di\s+thang|tiep\s+tuc)\b""",
        )
    private val ROUNDABOUT_EXIT_ORDINAL =
        Regex("""\b(?:take\s+the\s+)?(\d+|first|1st|second|2nd|third|3rd|fourth|4th)\s+exit\b""")

    private val DISTANCE_STRICT =
        Regex("""^[\d.,]+\s*(km|mi|m|ft|yd|mét|met|kilômét|kilomet)\.?$""", RegexOption.IGNORE_CASE)

    private val DISTANCE_PREFIX =
        Regex(
            """^[\d.,]+\s*(km|m|mi|ft|yd|mét|met|kilômét|kilomet)\b""",
            RegexOption.IGNORE_CASE,
        )
}
