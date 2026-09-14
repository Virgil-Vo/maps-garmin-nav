import 'package:flutter_test/flutter_test.dart';
import 'package:maps_garmin_nav/data/nav_models.dart';

void main() {
  test('parses a navigating payload', () {
    final instruction = NavInstruction.fromMap({
      's': 1,
      'm': 2,
      'd': '200 m',
      'r': 'Main St',
      'i': 'Turn left',
    });
    expect(instruction.status, NavStatus.navigating);
    expect(instruction.maneuver, Maneuver.left);
    expect(instruction.distance, '200 m');
    expect(instruction.road, 'Main St');
    expect(instruction.isActive, isTrue);
  });
}
