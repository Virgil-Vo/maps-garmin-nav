import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:maps_garmin_nav/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methods = MethodChannel('com.mapsgarmin.nav/methods');
  const events = EventChannel('com.mapsgarmin.nav/events');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (call) async {
          if (call.method == 'getWatchDisplaySettings') {
            return {
              'showManeuverIcon': true,
              'showDistance': true,
              'showStreetName': true,
              'showArrivalTime': false,
              'textScale': 1,
              'iconScale': 1,
            };
          }
          if (call.method == 'getStatus') {
            return {
              'notificationListenerEnabled': false,
              'batteryUnrestricted': false,
              'garmin': {
                'sdkReady': false,
                'garminConnectInstalled': false,
                'deviceConnected': false,
                'appInstalled': false,
              },
              'nav': {'s': 0, 'm': 0, 'd': '', 'r': '', 'i': ''},
            };
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          events,
          MockStreamHandler.inline(onListen: (arguments, eventsSink) {}),
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(events, null);
  });

  testWidgets('app shell shows permission and garmin sections', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: MapsGarminApp()));
    await tester.pump();
    expect(find.text('Maps Garmin Nav'), findsOneWidget);
    expect(find.text('Watch display'), findsOneWidget);
    expect(find.text('Permissions'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Start watch bridge'), 300);
    expect(find.text('Start watch bridge'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Garmin'), 300);
    expect(find.text('Garmin'), findsOneWidget);
  });
}
