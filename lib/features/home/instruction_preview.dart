import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:maps_garmin_nav/core/spacing.dart';
import 'package:maps_garmin_nav/data/nav_models.dart';
import 'package:maps_garmin_nav/providers/watch_display_settings_provider.dart';
import 'package:maps_garmin_nav/widgets/maneuver_icon.dart';

class InstructionPreview extends ConsumerWidget {
  const InstructionPreview({super.key, required this.instruction});

  final NavInstruction instruction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final active = instruction.isActive;
    final showArrivalTime = ref.watch(watchDisplaySettingsProvider).showArrivalTime;

    return Card(
      margin: const EdgeInsets.all(Spacing.md),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          children: [
            ManeuverIcon(
              maneuver: instruction.maneuver,
              instruction: instruction.instruction,
              size: 48,
              color: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    instruction.distance.isEmpty
                        ? (active
                              ? instruction.maneuver.label
                              : 'No active navigation')
                        : instruction.distance,
                    style: theme.textTheme.headlineSmall,
                  ),
                  if (showArrivalTime && instruction.arrivalTime.isNotEmpty) ...[
                    const SizedBox(height: Spacing.xs),
                    Text(
                      instruction.arrivalTime,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (instruction.instruction.isNotEmpty &&
                      instruction.instruction != instruction.road) ...[
                    const SizedBox(height: Spacing.xs),
                    Text(
                      instruction.instruction,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: Spacing.xs),
                  if (instruction.road.isNotEmpty)
                    Text(
                      instruction.road,
                      style: theme.textTheme.titleMedium,
                    )
                  else if (instruction.instruction.isEmpty)
                    Text(
                      'Start Google Maps navigation to preview the next turn.',
                      style: theme.textTheme.titleMedium,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
