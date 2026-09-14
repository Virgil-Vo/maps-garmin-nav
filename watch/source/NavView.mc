import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Timer;
import Toybox.WatchUi;

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
        drawManeuver(dc, width / 2, (height * 0.32).toNumber(), (width * 0.22).toNumber(), NavStore.maneuver);

        var distance = NavStore.distance.length() > 0 ? NavStore.distance : "--";
        dc.drawText(width / 2, (height * 0.55).toNumber(), Graphics.FONT_NUMBER_MEDIUM, distance, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var label = NavStore.road.length() > 0 ? NavStore.road : NavStore.instruction;
        drawWrapped(dc, label, (height * 0.74).toNumber(), (width * 0.78).toNumber());
    }

    function pulseBacklightIfNeeded() as Void {
        if (NavStore.maneuver != NavStore.lastManeuver && Attention has :backlight) {
            Attention.backlight(true);
        }
        NavStore.lastManeuver = NavStore.maneuver;
    }

    function drawManeuver(dc as Dc, cx as Number, cy as Number, size as Number, maneuver as Number) as Void {
        if (maneuver == 9) {
            dc.setPenWidth(4);
            dc.drawCircle(cx, cy, size);
            dc.fillCircle(cx, cy, 6);
            dc.drawText(cx, cy + size + 2, Graphics.FONT_XTINY, "RNDBT", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        if (maneuver == 11) {
            dc.fillCircle(cx, cy, size / 3);
            dc.drawText(cx, cy + size, Graphics.FONT_XTINY, "ARRIVE", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var angle = maneuverAngle(maneuver);
        var tip = rotate(0, -size, angle, cx, cy);
        var left = rotate((-size * 0.48).toNumber(), (size * 0.38).toNumber(), angle, cx, cy);
        var notch = rotate(0, (size * 0.12).toNumber(), angle, cx, cy);
        var right = rotate((size * 0.48).toNumber(), (size * 0.38).toNumber(), angle, cx, cy);
        dc.fillPolygon([tip, left, notch, right] as Array<Array<Numeric>>);
    }

    function maneuverAngle(maneuver as Number) as Float {
        if (maneuver == 2 || maneuver == 13) {
            return -Math.PI / 2;
        }
        if (maneuver == 3 || maneuver == 14) {
            return Math.PI / 2;
        }
        if (maneuver == 4) {
            return -Math.PI / 4;
        }
        if (maneuver == 5) {
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
        return 0.0;
    }

    function rotate(x as Number, y as Number, angle as Float, cx as Number, cy as Number) as Array<Numeric> {
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);
        var rx = cx + x * cos - y * sin;
        var ry = cy + x * sin + y * cos;
        return [rx, ry] as Array<Numeric>;
    }

    function drawWrapped(dc as Dc, text as String, y as Number, maxWidth as Number) as Void {
        if (text.length() == 0) {
            return;
        }
        var font = Graphics.FONT_SMALL;
        var lines = wrapText(dc, text, font, maxWidth);
        var lineHeight = dc.getFontHeight(font);
        var startY = y;
        if (lines.size() > 1) {
            startY = y - lineHeight / 2;
        }
        for (var i = 0; i < lines.size() && i < 3; i++) {
            dc.drawText(dc.getWidth() / 2, startY + i * lineHeight, font, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function wrapText(dc as Dc, text as String, font as FontDefinition, maxWidth as Number) as Array<String> {
        var lines = [] as Array<String>;
        var remaining = text;
        while (remaining.length() > 0 && lines.size() < 3) {
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
            if (space > 0) {
                lines.add(remaining.substring(0, space));
                remaining = remaining.substring(space + 1, remaining.length());
            } else {
                lines.add(chunk);
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
