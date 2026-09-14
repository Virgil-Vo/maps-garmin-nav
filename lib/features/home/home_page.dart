import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:maps_garmin_nav/core/spacing.dart';
import 'package:maps_garmin_nav/data/nav_bridge.dart';
import 'package:maps_garmin_nav/features/home/instruction_preview.dart';
import 'package:maps_garmin_nav/features/home/permission_tile.dart';
import 'package:maps_garmin_nav/features/home/status_row.dart';
import 'package:maps_garmin_nav/providers/companion_status_provider.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(companionStatusProvider);
    final lifecycle = useAppLifecycleState();

    useEffect(() {
      if (lifecycle == AppLifecycleState.resumed) {
        ref.read(companionStatusProvider.notifier).refresh();
      }
      return null;
    }, [lifecycle]);

    final garmin = status.garmin;
    return ListView(
      padding: const EdgeInsets.only(bottom: Spacing.xl),
      children: [
        InstructionPreview(instruction: status.instruction),
        const _SectionTitle('Permissions'),
        PermissionTile(
          title: 'Notification access',
          subtitle: 'Required to read Google Maps turn-by-turn notifications',
          granted: status.notificationListenerEnabled,
          actionLabel: 'Allow',
          onPressed: () {
            ref
                .read(companionStatusProvider.notifier)
                .openNotificationListenerSettings();
          },
        ),
        PermissionTile(
          title: 'Battery optimization',
          subtitle: 'Let the app keep running while the screen is off',
          granted: status.batteryUnrestricted,
          actionLabel: 'Allow',
          onPressed: () {
            ref
                .read(companionStatusProvider.notifier)
                .requestBatteryOptimization();
          },
        ),
        PermissionTile(
          title: 'Notifications',
          subtitle: 'Shows the background navigation bridge status',
          granted: status.notificationsAllowed,
          actionLabel: 'Allow',
          onPressed: () {
            ref.read(companionStatusProvider.notifier).requestNotifications();
          },
        ),
        PermissionTile(
          title: 'Bluetooth',
          subtitle: 'Used by the Garmin Connect IQ companion SDK',
          granted: status.bluetoothAllowed,
          actionLabel: 'Allow',
          onPressed: () {
            ref.read(companionStatusProvider.notifier).requestBluetooth();
          },
        ),
        Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: FilledButton(
            onPressed: () {
              ref.read(companionStatusProvider.notifier).startBridge();
            },
            child: const Text('Start watch bridge'),
          ),
        ),
        const _SectionTitle('Garmin'),
        StatusRow(
          label: 'Garmin Connect',
          value: garmin.garminConnectInstalled ? 'Installed' : 'Missing',
          ok: garmin.garminConnectInstalled,
        ),
        StatusRow(
          label: 'Connect IQ SDK',
          value: garmin.sdkReady ? 'Ready' : 'Not ready',
          ok: garmin.sdkReady,
        ),
        StatusRow(
          label: 'Watch',
          value: garmin.deviceConnected
              ? (garmin.deviceName ?? 'Connected')
              : (garmin.deviceName ?? 'Not connected'),
          ok: garmin.deviceConnected,
        ),
        StatusRow(
          label: 'Watch app',
          value: garmin.appInstalled ? 'Installed' : 'Not installed',
          ok: garmin.appInstalled,
        ),
        if (garmin.lastError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.xs,
              Spacing.md,
              Spacing.sm,
            ),
            child: Text(
              garmin.lastError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          child: OutlinedButton(
            onPressed: garmin.deviceConnected
                ? () => NavBridge.instance.openWatchApp()
                : null,
            child: const Text('Open watch app'),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.lg,
        Spacing.md,
        Spacing.xs,
      ),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
