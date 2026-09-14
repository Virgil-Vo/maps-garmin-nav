import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:maps_garmin_nav/data/nav_bridge.dart';
import 'package:maps_garmin_nav/data/watch_display_settings.dart';

final watchDisplaySettingsProvider =
    NotifierProvider<WatchDisplaySettingsNotifier, WatchDisplaySettings>(
      WatchDisplaySettingsNotifier.new,
    );

class WatchDisplaySettingsNotifier extends Notifier<WatchDisplaySettings> {
  @override
  WatchDisplaySettings build() => const WatchDisplaySettings();

  Future<void> loadFromPlatform() async {
    try {
      final map = await NavBridge.instance.getWatchDisplaySettings();
      state = WatchDisplaySettings.fromMap(map);
    } catch (_) {
      // Keep defaults when the platform channel is unavailable (e.g. hot reload).
    }
  }

  Future<void> replace(WatchDisplaySettings next) async {
    state = next;
    await NavBridge.instance.setWatchDisplaySettings(next.toMap());
  }
}
