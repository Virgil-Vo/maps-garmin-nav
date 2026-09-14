import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:maps_garmin_nav/core/connect_iq_flags.dart';
import 'package:maps_garmin_nav/data/nav_bridge.dart';
import 'package:maps_garmin_nav/data/nav_models.dart';
import 'package:maps_garmin_nav/providers/watch_display_settings_provider.dart';
import 'package:permission_handler/permission_handler.dart';

final companionStatusProvider =
    NotifierProvider<CompanionStatusNotifier, CompanionStatus>(
      CompanionStatusNotifier.new,
    );

class CompanionStatusNotifier extends Notifier<CompanionStatus> {
  @override
  CompanionStatus build() {
    ref.listen<AsyncValue<Map<dynamic, dynamic>>>(companionEventsProvider, (
      _,
      next,
    ) {
      final event = next.asData?.value;
      if (event == null) {
        return;
      }
      _applyEvent(event);
    });
    Future.microtask(refresh);
    return CompanionStatus.initial();
  }

  Future<void> refresh() async {
    try {
      final native = await NavBridge.instance.getStatus();
      final notifications = await _safeGranted(Permission.notification);
      final bluetooth = await _bluetoothGranted();
      final garminRaw = native['garmin'];
      final navRaw = native['nav'];
      state = state.copyWith(
        notificationListenerEnabled:
            native['notificationListenerEnabled'] == true,
        batteryUnrestricted: native['batteryUnrestricted'] == true,
        notificationsAllowed: notifications,
        bluetoothAllowed: bluetooth,
        garmin: GarminLinkStatus.fromMap(
          garminRaw is Map ? Map<dynamic, dynamic>.from(garminRaw) : null,
        ),
        instruction: NavInstruction.fromMap(
          navRaw is Map ? Map<dynamic, dynamic>.from(navRaw) : const {},
        ),
      );
    } catch (_) {
      // Keep the last known status if the platform channel is unavailable.
    }
    await ref.read(watchDisplaySettingsProvider.notifier).loadFromPlatform();
  }

  Future<void> requestNotifications() async {
    await Permission.notification.request();
    await refresh();
  }

  Future<void> requestBluetooth() async {
    await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
    await refresh();
  }

  Future<void> requestBatteryOptimization() async {
    await Permission.ignoreBatteryOptimizations.request();
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await NavBridge.instance.openBatteryOptimizationSettings();
    }
    await refresh();
  }

  Future<void> openNotificationListenerSettings() async {
    await NavBridge.instance.openNotificationListenerSettings();
  }

  Future<void> startBridge() async {
    if (connectIqTetheredSimulator) {
      await NavBridge.instance.setTethered(true);
    }
    await NavBridge.instance.initializeGarmin();
    await NavBridge.instance.startForeground();
    await refresh();
  }

  void _applyEvent(Map<dynamic, dynamic> event) {
    final type = event['type'];
    final payload = event['payload'];
    if (type == 'nav' && payload is Map) {
      state = state.copyWith(
        instruction: NavInstruction.fromMap(Map<dynamic, dynamic>.from(payload)),
      );
    } else if (type == 'garmin' && payload is Map) {
      state = state.copyWith(
        garmin: GarminLinkStatus.fromMap(Map<dynamic, dynamic>.from(payload)),
      );
    }
  }

  Future<bool> _bluetoothGranted() async {
    final scan = await _safeGranted(Permission.bluetoothScan);
    final connect = await _safeGranted(Permission.bluetoothConnect);
    return scan && connect;
  }

  Future<bool> _safeGranted(Permission permission) async {
    try {
      return await permission.isGranted;
    } catch (_) {
      return false;
    }
  }
}

final companionEventsProvider = StreamProvider<Map<dynamic, dynamic>>((ref) {
  return NavBridge.instance.events();
});
