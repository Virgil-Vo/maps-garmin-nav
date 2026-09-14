import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:maps_garmin_nav/core/spacing.dart';
import 'package:maps_garmin_nav/data/watch_display_settings.dart';
import 'package:maps_garmin_nav/providers/watch_display_settings_provider.dart';

class WatchDisplaySettingsSection extends HookConsumerWidget {
  const WatchDisplaySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      ref.read(watchDisplaySettingsProvider.notifier).loadFromPlatform();
      return null;
    }, const []);

    final settings = ref.watch(watchDisplaySettingsProvider);
    return _WatchDisplaySettingsBody(settings: settings);
  }
}

class _WatchDisplaySettingsBody extends ConsumerWidget {
  const _WatchDisplaySettingsBody({required this.settings});

  final WatchDisplaySettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(watchDisplaySettingsProvider.notifier);

    Future<void> update(WatchDisplaySettings next) async {
      try {
        await notifier.replace(next);
      } on PlatformException catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error.message ?? 'Could not save watch display settings',
              ),
            ),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save watch display settings'),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text('Turn arrow'),
          subtitle: const Text('Direction icon above the distance'),
          value: settings.showManeuverIcon,
          onChanged: (value) {
            update(settings.copyWith(showManeuverIcon: value));
          },
        ),
        SwitchListTile(
          title: const Text('Distance'),
          subtitle: const Text('Distance to the next turn'),
          value: settings.showDistance,
          onChanged: (value) {
            update(settings.copyWith(showDistance: value));
          },
        ),
        SwitchListTile(
          title: const Text('Street name'),
          subtitle: const Text('Road to turn onto (auto-sized, up to 3 lines)'),
          value: settings.showStreetName,
          onChanged: (value) {
            update(settings.copyWith(showStreetName: value));
          },
        ),
        SwitchListTile(
          title: const Text('Arrival time'),
          subtitle: const Text('ETA from Maps (e.g. Arrive 4:08 PM)'),
          value: settings.showArrivalTime,
          onChanged: (value) {
            update(settings.copyWith(showArrivalTime: value));
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.sm,
            Spacing.md,
            Spacing.md,
          ),
          child: Text(
            'Changes sync when the watch is connected. Navigation updates also carry the latest settings.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
