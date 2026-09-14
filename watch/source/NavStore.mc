import Toybox.Lang;

module NavStore {
    var status as Number = 0;
    var maneuver as Number = 0;
    var distance as String = "";
    var road as String = "";
    var instruction as String = "";
    var lastManeuver as Number = -1;

    function apply(data as Object?) as Void {
        if (data == null || !(data instanceof Dictionary)) {
            return;
        }
        var dict = data as Dictionary;
        var nextStatus = dict.get("s");
        var nextManeuver = dict.get("m");
        var nextDistance = dict.get("d");
        var nextRoad = dict.get("r");
        var nextInstruction = dict.get("i");

        if (nextStatus instanceof Number) {
            status = nextStatus as Number;
        }
        if (nextManeuver instanceof Number) {
            lastManeuver = maneuver;
            maneuver = nextManeuver as Number;
        }
        if (nextDistance instanceof String) {
            distance = nextDistance as String;
        }
        if (nextRoad instanceof String) {
            road = nextRoad as String;
        }
        if (nextInstruction instanceof String) {
            instruction = nextInstruction as String;
        } else if (road.length() > 0) {
            instruction = "";
        }
    }
}
