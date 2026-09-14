package com.mapsgarmin.maps_garmin_nav.nav

import org.junit.Assert.assertEquals
import org.junit.Test

class ManeuverClassifierTest {
    @Test
    fun etaArrivePrefix_doesNotClassifyAsArrive() {
        val maneuver =
            ManeuverClassifier.classify(
                "Arrive 4:08 PM · Turn left onto Pham Hung",
            )
        assertEquals(Maneuver.LEFT, maneuver)
    }

    @Test
    fun peelDistance_splitsBulletLine() {
        val (distance, rest) =
            ManeuverClassifier.peelDistanceAndRest(
                "120 m · Turn left after Cơm Tấm Mai Linh (on the left) onto Đ. Phạm Hùng",
            )
        assertEquals("120 m", distance)
        assertEquals(
            "Turn left after Cơm Tấm Mai Linh (on the left) onto Đ. Phạm Hùng",
            rest,
        )
    }

    @Test
    fun classify_turnLeft_notArriveWhenEtaSeparate() {
        val maneuver =
            ManeuverClassifier.classify(
                "Turn left after Cơm Tấm Mai Linh (on the left) onto Đ. Phạm Hùng",
            )
        assertEquals(Maneuver.LEFT, maneuver)
    }

    @Test
    fun targetStreet_prefersOntoClause() {
        val street =
            ManeuverClassifier.targetStreet(
                "Duong Pham Hung",
                "Turn left after Com Tam onto Duong Pham Hung",
            )
        assertEquals("Duong Pham Hung", street)
    }

    @Test
    fun splitInstruction_ignoresOnTheLeft_beforeOnto() {
        val line =
            "Turn left after Cơm Tấm Mai Linh (on the left) onto Đ. Phạm Hùng"
        val (turn, road) = ManeuverClassifier.splitInstruction(line)
        assertEquals("Đ. Phạm Hùng", road)
        assertEquals("Turn left after Cơm Tấm Mai Linh (on the left)", turn)
    }

    @Test
    fun turnPhrase_classifiesLeft() {
        assertEquals(
            Maneuver.LEFT,
            ManeuverClassifier.classify("Turn left after Com Tam onto Duong Pham Hung"),
        )
    }

    @Test
    fun roundabout_continueStraight_usesStraightExitIcon() {
        assertEquals(
            Maneuver.ROUNDABOUT_STRAIGHT,
            ManeuverClassifier.classify("At the roundabout, continue straight"),
        )
    }

    @Test
    fun roundabout_turnLeft_usesLeftExitIcon() {
        assertEquals(
            Maneuver.ROUNDABOUT_LEFT,
            ManeuverClassifier.classify("At the roundabout, turn left onto Main St"),
        )
        assertEquals(
            Maneuver.ROUNDABOUT_LEFT,
            ManeuverClassifier.classify("At the roundabout, turn left onto Liên Tỉnh 5"),
        )
    }

    @Test
    fun roundabout_turnRight_usesRightExitIcon() {
        assertEquals(
            Maneuver.ROUNDABOUT_RIGHT,
            ManeuverClassifier.classify("At the roundabout, turn right onto Highway 1"),
        )
    }

    @Test
    fun roundabout_exitNumbers_rightHandTraffic() {
        assertEquals(
            Maneuver.ROUNDABOUT_RIGHT,
            ManeuverClassifier.classify("At the roundabout, take the 1st exit"),
        )
        assertEquals(
            Maneuver.ROUNDABOUT_STRAIGHT,
            ManeuverClassifier.classify("At the roundabout, take the 2nd exit"),
        )
        assertEquals(
            Maneuver.ROUNDABOUT_LEFT,
            ManeuverClassifier.classify("At the roundabout, take the 3rd exit"),
        )
    }

    @Test
    fun roundabout_withoutDirection_isStraightThrough() {
        assertEquals(
            Maneuver.ROUNDABOUT_STRAIGHT,
            ManeuverClassifier.classify("At the roundabout"),
        )
    }
}
