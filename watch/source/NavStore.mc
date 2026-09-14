import Toybox.Lang;

module NavStore {
    var status as Number = 0;
    var maneuver as Number = 0;
    var distance as String = "";
    var road as String = "";
    var instruction as String = "";
    var lastManeuver as Number = -1;

    var showManeuverIcon as Boolean = true;
    var showDistance as Boolean = true;
    var showStreetName as Boolean = true;
    var showArrivalTime as Boolean = false;
    var arrivalTime as String = "";
    var textScale as Number = 1;
    var iconScale as Number = 1;

    function apply(data as Object?) as Void {
        if (data == null || !(data instanceof Dictionary)) {
            return;
        }
        var dict = data as Dictionary;
        applyDisplay(dict);

        var msgType = dict.get("t");
        if (msgType != null && msgType instanceof String && (msgType as String).equals("c")) {
            return;
        }

        var nextStatus = dict.get("s");
        var nextManeuver = dict.get("m");
        var nextDistance = dict.get("d");
        var nextRoad = dict.get("r");
        var nextInstruction = dict.get("i");
        var nextArrival = dict.get("a");

        if (nextStatus instanceof Number) {
            status = nextStatus as Number;
        }
        if (nextManeuver instanceof Number) {
            lastManeuver = maneuver;
            maneuver = (nextManeuver as Number).toNumber();
        }
        if (nextDistance instanceof String) {
            var incomingDistance = nextDistance as String;
            if (incomingDistance.length() > 0) {
                distance = incomingDistance;
            }
        }
        if (nextRoad instanceof String) {
            road = nextRoad as String;
        }
        if (nextInstruction instanceof String) {
            instruction = nextInstruction as String;
        } else if (road.length() > 0) {
            instruction = "";
        }
        if (nextArrival instanceof String) {
            arrivalTime = nextArrival as String;
        } else if (!showArrivalTime) {
            arrivalTime = "";
        }
    }

    function applyDisplay(dict as Dictionary) as Void {
        var nextShowDistance = dict.get("sd");
        if (nextShowDistance instanceof Number) {
            showDistance = (nextShowDistance as Number) != 0;
        }
        var nextShowLabel = dict.get("sl");
        if (nextShowLabel instanceof Number) {
            showStreetName = (nextShowLabel as Number) != 0;
        }
        var nextShowIcon = dict.get("si");
        if (nextShowIcon instanceof Number) {
            showManeuverIcon = (nextShowIcon as Number) != 0;
        }
        var nextShowArrival = dict.get("sa");
        if (nextShowArrival instanceof Number) {
            showArrivalTime = (nextShowArrival as Number) != 0;
        }
        var nextTextScale = dict.get("ts");
        if (nextTextScale instanceof Number) {
            textScale = clampScale(nextTextScale as Number);
        }
        var nextIconScale = dict.get("is");
        if (nextIconScale instanceof Number) {
            iconScale = clampScale(nextIconScale as Number);
        }
    }

    function clampScale(value as Number) as Number {
        if (value < 0) {
            return 0;
        }
        if (value > 2) {
            return 2;
        }
        return value;
    }
}
