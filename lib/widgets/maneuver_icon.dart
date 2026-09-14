import 'package:flutter/material.dart';
import 'package:maps_garmin_nav/data/nav_models.dart';

/// Same roundabout rule as NavView.mc: instruction text wins over `m`.
/// Roundabout = the matching turn arrow with a circle on top.
class ManeuverIcon extends StatelessWidget {
  const ManeuverIcon({
    super.key,
    required this.maneuver,
    required this.size,
    required this.color,
    this.instruction = '',
  });

  final Maneuver maneuver;
  final double size;
  final Color color;
  final String instruction;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveManeuver(maneuver, instruction);
    if (_isRoundabout(resolved)) {
      return SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(_turnArrow(resolved), size: size, color: color),
            CustomPaint(
              size: Size.square(size),
              painter: _CircleOnTopPainter(color: color),
            ),
          ],
        ),
      );
    }
    return Icon(resolved.icon, size: size, color: color);
  }

  static bool _isRoundabout(Maneuver maneuver) {
    return maneuver == Maneuver.roundabout ||
        maneuver == Maneuver.roundaboutStraight ||
        maneuver == Maneuver.roundaboutLeft ||
        maneuver == Maneuver.roundaboutRight;
  }

  static IconData _turnArrow(Maneuver maneuver) {
    return switch (maneuver) {
      Maneuver.roundaboutLeft => Icons.turn_left,
      Maneuver.roundaboutRight => Icons.turn_right,
      _ => Icons.arrow_upward,
    };
  }

  static Maneuver resolveManeuver(Maneuver maneuver, String instruction) {
    final text = instruction.toLowerCase();
    final roundabout =
        _isRoundabout(maneuver) ||
        text.contains('roundabout') ||
        text.contains('rotary') ||
        text.contains('vong');
    if (!roundabout) {
      return maneuver;
    }
    if (_has(text, const [
      'turn left',
      'left turn',
      're trai',
      'queo trai',
    ])) {
      return Maneuver.roundaboutLeft;
    }
    if (_has(text, const [
      'turn right',
      'right turn',
      're phai',
      'queo phai',
    ])) {
      return Maneuver.roundaboutRight;
    }
    if (_has(text, const ['straight', 'continue'])) {
      return Maneuver.roundaboutStraight;
    }
    return maneuver == Maneuver.roundaboutLeft ||
            maneuver == Maneuver.roundaboutRight
        ? maneuver
        : Maneuver.roundaboutStraight;
  }

  static bool _has(String text, List<String> needles) {
    return needles.any(text.contains);
  }
}

class _CircleOnTopPainter extends CustomPainter {
  _CircleOnTopPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide * 0.28;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * 0.06;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, paint);
  }

  @override
  bool shouldRepaint(covariant _CircleOnTopPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
