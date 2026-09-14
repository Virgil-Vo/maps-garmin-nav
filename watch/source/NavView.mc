import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

typedef ManeuverPoint as Graphics.Point2D;
typedef ManeuverPolygon as Array<ManeuverPoint>;

class NavView extends WatchUi.View {
    private var _timer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        if (_timer == null) {
            _timer = new Timer.Timer();
        }
        _timer.start(method(:onTick), 1000, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
        }
    }

    function onTick() as Void {
        if (NavStore.status == 1) {
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        if (NavStore.status == 0) {
            dc.drawText(width / 2, height / 2, Graphics.FONT_MEDIUM, "Waiting for Maps", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        if (NavStore.status == 2) {
            dc.drawText(width / 2, height / 2, Graphics.FONT_LARGE, "Rerouting", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        if (NavStore.status == 3) {
            dc.drawText(width / 2, height / 2, Graphics.FONT_MEDIUM, "Navigation ended", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        pulseBacklightIfNeeded();
        drawNavigating(dc, width, height);
    }

    // Clock, arrow, distance, instruction, street, optional ETA.
    function drawNavigating(dc as Dc, width as Number, height as Number) as Void {
        drawClock(dc, width, height);
        var y = (height * 0.18).toNumber();

        if (NavStore.showManeuverIcon) {
            var iconRadius = (width * 0.11).toNumber();
            var iconCenterY = y + iconRadius;
            drawManeuver(dc, width / 2, iconCenterY, iconRadius);
            y = iconCenterY + iconRadius + (height * 0.04).toNumber();
        }

        if (NavStore.showDistance) {
            var distance = NavStore.distance.length() > 0 ? NavStore.distance : "--";
            drawDistance(dc, distance, width, height, y);
            y += (height * 0.13).toNumber();
        }

        if (NavStore.instruction.length() > 0 && !(NavStore.instruction.equals(NavStore.road))) {
            drawTurnInstruction(dc, NavStore.instruction, width, height, y);
            y += (height * 0.12).toNumber();
        }

        if (NavStore.showStreetName && NavStore.road.length() > 0) {
            drawStreetLabel(dc, NavStore.road, width, height, y);
            y += (height * 0.16).toNumber();
        }

        if (NavStore.showArrivalTime && NavStore.arrivalTime.length() > 0) {
            drawArrivalTime(dc, NavStore.arrivalTime, width, height, y);
        }
    }

    function drawClock(dc as Dc, width as Number, height as Number) as Void {
        var clock = System.getClockTime();
        var text = pad2(clock.hour) + ":" + pad2(clock.min);
        var y = (height * 0.08).toNumber();
        dc.drawText(width / 2, y, Graphics.FONT_XTINY, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function pad2(value as Number) as String {
        if (value < 10) {
            return "0" + value.toString();
        }
        return value.toString();
    }

    function drawTurnInstruction(dc as Dc, text as String, width as Number, height as Number, y as Number) as Void {
        var font = Graphics.FONT_XTINY;
        var maxWidth = maxTextWidth(width, height, y);
        var lines = wrapText(dc, text, font, maxWidth, 2);
        if (lines.size() == 0) {
            return;
        }
        if (lines.size() > 2) {
            lines = packIntoLines(dc, text, font, maxWidth, 2);
        }
        var lineHeight = dc.getFontHeight(font);
        var startY = y - ((lines.size() - 1) * lineHeight) / 2;
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(width / 2, startY + i * lineHeight, font, lines[i], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function drawArrivalTime(dc as Dc, arrival as String, width as Number, height as Number, y as Number) as Void {
        var maxWidth = maxTextWidth(width, height, y);
        var font = Graphics.FONT_XTINY;
        var line = arrival;
        if (dc.getTextWidthInPixels(line, font) > maxWidth) {
            line = wrapLineToWidth(dc, line, font, maxWidth);
        }
        dc.drawText(width / 2, y, font, line, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawDistance(dc as Dc, distance as String, width as Number, height as Number, y as Number) as Void {
        var maxWidth = maxTextWidth(width, height, y);
        var font = fitDistanceFont(dc, distance, maxWidth);
        dc.drawText(width / 2, y, font, distance, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function fitDistanceFont(dc as Dc, distance as String, maxWidth as Number) as FontDefinition {
        var fonts = distanceFontCandidates(distance);
        var chosen = fonts[fonts.size() - 1];
        for (var i = 0; i < fonts.size(); i++) {
            var candidate = fonts[i];
            if (dc.getTextWidthInPixels(distance, candidate) <= maxWidth) {
                return candidate;
            }
            chosen = candidate;
        }
        return chosen;
    }

    function distanceFontCandidates(distance as String) as Array<FontDefinition> {
        if (distanceNeedsTextFont(distance)) {
            return [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL] as Array<FontDefinition>;
        }
        return [Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_XTINY] as Array<FontDefinition>;
    }

    // Usable horizontal span on a round display at a given row (chord of the circle).
    function maxTextWidth(width as Number, height as Number, y as Number) as Number {
        var radius = width / 2;
        var centerY = height / 2;
        var dy = y - centerY;
        if (dy < 0) {
            dy = -dy;
        }
        if (dy >= radius) {
            return (width * 0.55).toNumber();
        }
        var inside = radius * radius - dy * dy;
        if (inside < 0) {
            inside = 0;
        }
        var chord = (2 * Math.sqrt(inside.toFloat())).toNumber();
        if (chord > width) {
            chord = width;
        }
        return (chord * 0.90).toNumber();
    }

    function distanceNeedsTextFont(distance as String) as Boolean {
        for (var i = 0; i < distance.length(); i++) {
            var ch = distance.substring(i, i + 1);
            if (isDigitChar(ch) || ch.equals(" ") || ch.equals(".") || ch.equals(",") || ch.equals("-")) {
                continue;
            }
            return true;
        }
        return false;
    }

    function isDigitChar(ch as String) as Boolean {
        return ch.equals("0") || ch.equals("1") || ch.equals("2") || ch.equals("3") || ch.equals("4")
            || ch.equals("5") || ch.equals("6") || ch.equals("7") || ch.equals("8") || ch.equals("9");
    }

    function streetFontCandidates() as Array<FontDefinition> {
        return [
            Graphics.FONT_XTINY,
            Graphics.FONT_TINY,
        ] as Array<FontDefinition>;
    }

    function drawStreetLabel(dc as Dc, text as String, width as Number, height as Number, labelY as Number) as Void {
        if (text.length() == 0) {
            return;
        }
        var maxLines = 3;
        var fonts = streetFontCandidates();
        var font = fonts[fonts.size() - 1];
        var fitted = wrapText(dc, text, font, maxTextWidth(width, height, labelY), 8);
        for (var i = 0; i < fonts.size(); i++) {
            var candidate = fonts[i];
            var maxWidth = maxTextWidth(width, height, labelY);
            var probe = wrapText(dc, text, candidate, maxWidth, 8);
            if (probe.size() <= maxLines) {
                font = candidate;
                fitted = probe;
                break;
            }
            font = candidate;
            fitted = probe;
        }
        if (fitted.size() > maxLines) {
            fitted = packIntoLines(dc, text, font, maxTextWidth(width, height, labelY), maxLines);
        }
        drawStreetLines(dc, fitted, labelY, font, maxLines, width, height);
    }

    function packIntoLines(dc as Dc, text as String, font as FontDefinition, maxWidth as Number, lineCount as Number) as Array<String> {
        var lines = [] as Array<String>;
        for (var i = 0; i < lineCount; i++) {
            lines.add("");
        }
        var remaining = text;
        var lineIndex = 0;
        while (remaining.length() > 0 && lineIndex < lineCount) {
            var line = lines[lineIndex];
            var added = false;
            var space = firstSpace(remaining);
            if (space > 0) {
                var word = remaining.substring(0, space);
                var candidate = line.length() == 0 ? word : line + " " + word;
                if (dc.getTextWidthInPixels(candidate, font) <= maxWidth) {
                    lines[lineIndex] = candidate;
                    remaining = remaining.substring(space + 1, remaining.length());
                    added = true;
                }
            }
            if (!added) {
                var cut = 1;
                while (cut <= remaining.length()) {
                    var chunk = remaining.substring(0, cut);
                    var candidate = line.length() == 0 ? chunk : line + chunk;
                    if (dc.getTextWidthInPixels(candidate, font) > maxWidth) {
                        break;
                    }
                    cut += 1;
                }
                cut -= 1;
                if (cut < 1) {
                    if (line.length() > 0) {
                        lineIndex += 1;
                        continue;
                    }
                    cut = 1;
                }
                var chunk = remaining.substring(0, cut);
                lines[lineIndex] = line.length() == 0 ? chunk : line + chunk;
                remaining = remaining.substring(cut, remaining.length());
            }
            if (dc.getTextWidthInPixels(lines[lineIndex], font) >= maxWidth || !added) {
                lineIndex += 1;
            }
        }
        return lines;
    }

    function firstSpace(text as String) as Number {
        for (var i = 0; i < text.length(); i++) {
            if (text.substring(i, i + 1).equals(" ")) {
                return i;
            }
        }
        return -1;
    }

    function drawStreetLines(dc as Dc, lines as Array<String>, y as Number, font as FontDefinition, maxLines as Number, width as Number, height as Number) as Void {
        var lineHeight = dc.getFontHeight(font);
        var count = lines.size();
        if (count > maxLines) {
            count = maxLines;
        }
        for (var i = 0; i < count; i++) {
            var lineY = y + i * lineHeight;
            var maxWidth = maxTextWidth(width, height, lineY);
            var line = lines[i];
            if (dc.getTextWidthInPixels(line, font) > maxWidth) {
                line = wrapLineToWidth(dc, line, font, maxWidth);
            }
            dc.drawText(width / 2, lineY, font, line, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function wrapLineToWidth(dc as Dc, text as String, font as FontDefinition, maxWidth as Number) as String {
        if (text.length() == 0 || dc.getTextWidthInPixels(text, font) <= maxWidth) {
            return text;
        }
        var cut = text.length();
        while (cut > 1 && dc.getTextWidthInPixels(text.substring(0, cut), font) > maxWidth) {
            cut -= 1;
        }
        if (cut < 1) {
            cut = 1;
        }
        return text.substring(0, cut);
    }

    function pulseBacklightIfNeeded() as Void {
        if (NavStore.maneuver != NavStore.lastManeuver && Attention has :backlight) {
            Attention.backlight(true);
        }
        NavStore.lastManeuver = NavStore.maneuver;
    }

    function drawManeuver(dc as Dc, cx as Number, cy as Number, size as Number) as Void {
        var maneuver = NavStore.maneuver;
        if (isRoundaboutStep(maneuver, NavStore.instruction)) {
            drawRoundabout(dc, cx, cy, size, roundaboutExit(maneuver, NavStore.instruction));
            return;
        }
        if (maneuver == 11) {
            drawArriveFlag(dc, cx, cy, size);
            return;
        }
        if (maneuver == 10) {
            drawArrow(dc, cx, cy, (size * 0.72).toNumber(), -Math.PI / 4);
            drawArrow(dc, cx, cy, (size * 0.55).toNumber(), Math.PI / 4);
            return;
        }

        var arrowSize = (size * 0.85).toNumber();
        if (maneuver == 0) {
            drawArrow(dc, cx, cy, arrowSize, 0.0);
            return;
        }
        drawArrow(dc, cx, cy, arrowSize, maneuverAngle(maneuver));
    }

    function isRoundaboutStep(maneuver as Number, instruction as String) as Boolean {
        if (maneuver == 9 || maneuver == 15 || maneuver == 16 || maneuver == 17) {
            return true;
        }
        return textHas(instruction, "roundabout") || textHas(instruction, "rotary") || textHas(instruction, "vong");
    }

    // 0 = through, 1 = left, 2 = right. Instruction text wins over m.
    function roundaboutExit(maneuver as Number, instruction as String) as Number {
        if (textHas(instruction, "turn left") || textHas(instruction, "left turn") || textHas(instruction, "re trai") || textHas(instruction, "queo trai")) {
            return 1;
        }
        if (textHas(instruction, "turn right") || textHas(instruction, "right turn") || textHas(instruction, "re phai") || textHas(instruction, "queo phai")) {
            return 2;
        }
        if (textHas(instruction, "straight") || textHas(instruction, "continue")) {
            return 0;
        }
        if (maneuver == 16) {
            return 1;
        }
        if (maneuver == 17) {
            return 2;
        }
        return 0;
    }

    function textHas(haystack as String, needle as String) as Boolean {
        if (haystack.length() == 0 || needle.length() == 0) {
            return false;
        }
        var hay = haystack.toLower();
        var need = needle.toLower();
        return hay.find(need) != null;
    }

    // Same turn arrow as left/right/straight, with a ring drawn on top.
    function drawRoundabout(dc as Dc, cx as Number, cy as Number, size as Number, dir as Number) as Void {
        var angle = 0.0;
        if (dir == 1) {
            angle = -Math.PI / 2;
        }
        if (dir == 2) {
            angle = Math.PI / 2;
        }
        drawArrow(dc, cx, cy, (size * 0.85).toNumber(), angle);
        dc.setPenWidth(penAtLeast(size, 10));
        dc.drawCircle(cx, cy, (size * 0.42).toNumber());
    }

    function penAtLeast(size as Number, divisor as Number) as Number {
        var pen = (size / divisor).toNumber();
        if (pen < 2) {
            return 2;
        }
        return pen;
    }

    function drawArriveFlag(dc as Dc, cx as Number, cy as Number, size as Number) as Void {
        dc.setPenWidth(2);
        var poleTop = cy - size;
        var poleBottom = cy + (size / 2).toNumber();
        dc.drawLine(cx, poleTop, cx, poleBottom);
        var flagW = (size * 0.55).toNumber();
        var flagH = (size * 0.38).toNumber();
        var fx = cx;
        var fy = poleTop;
        dc.fillPolygon([
            [fx, fy] as Graphics.Point2D,
            [fx + flagW, fy + (flagH / 2).toNumber()] as Graphics.Point2D,
            [fx, fy + flagH] as Graphics.Point2D,
        ] as ManeuverPolygon);
        dc.fillCircle(cx, poleBottom, (size * 0.12).toNumber());
    }

    function drawArrow(dc as Dc, cx as Number, cy as Number, size as Number, angle as Float) as Void {
        var tip = rotate(0, -size, angle, cx, cy);
        var left = rotate((-size * 0.48).toNumber(), (size * 0.38).toNumber(), angle, cx, cy);
        var notch = rotate(0, (size * 0.12).toNumber(), angle, cx, cy);
        var right = rotate((size * 0.48).toNumber(), (size * 0.38).toNumber(), angle, cx, cy);
        dc.fillPolygon([
            tip as Graphics.Point2D,
            left as Graphics.Point2D,
            notch as Graphics.Point2D,
            right as Graphics.Point2D,
        ] as ManeuverPolygon);
    }

    function maneuverAngle(maneuver as Number) as Float {
        if (maneuver == 2) {
            return -Math.PI / 2;
        }
        if (maneuver == 3) {
            return Math.PI / 2;
        }
        if (maneuver == 4 || maneuver == 13) {
            return -Math.PI / 4;
        }
        if (maneuver == 5 || maneuver == 14) {
            return Math.PI / 4;
        }
        if (maneuver == 6) {
            return -Math.PI * 3 / 4;
        }
        if (maneuver == 7) {
            return Math.PI * 3 / 4;
        }
        if (maneuver == 8) {
            return Math.PI;
        }
        if (maneuver == 12) {
            return Math.PI / 2;
        }
        return 0.0;
    }

    function rotate(x as Number, y as Number, angle as Float, cx as Number, cy as Number) as ManeuverPoint {
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);
        var rx = (cx + x * cos - y * sin).toNumber();
        var ry = (cy + x * sin + y * cos).toNumber();
        return [rx, ry] as Graphics.Point2D;
    }

    function wrapText(dc as Dc, text as String, font as FontDefinition, maxWidth as Number, maxLines as Number) as Array<String> {
        var lines = [] as Array<String>;
        var remaining = text;
        while (remaining.length() > 0 && lines.size() < maxLines) {
            if (dc.getTextWidthInPixels(remaining, font) <= maxWidth) {
                lines.add(remaining);
                break;
            }
            var cut = remaining.length();
            while (cut > 1 && dc.getTextWidthInPixels(remaining.substring(0, cut), font) > maxWidth) {
                cut -= 1;
            }
            var chunk = remaining.substring(0, cut);
            var space = lastSpace(chunk);
            if (space > 0 && dc.getTextWidthInPixels(remaining.substring(0, space), font) <= maxWidth) {
                lines.add(remaining.substring(0, space));
                remaining = remaining.substring(space + 1, remaining.length());
            } else {
                if (cut < 1) {
                    cut = 1;
                }
                lines.add(remaining.substring(0, cut));
                remaining = remaining.substring(cut, remaining.length());
            }
        }
        return lines;
    }

    function lastSpace(text as String) as Number {
        var index = -1;
        for (var i = 0; i < text.length(); i++) {
            if (text.substring(i, i + 1).equals(" ")) {
                index = i;
            }
        }
        return index;
    }
}
