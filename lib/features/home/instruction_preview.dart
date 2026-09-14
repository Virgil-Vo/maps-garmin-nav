import 'package:flutter/material.dart';
import 'package:maps_garmin_nav/core/spacing.dart';
import 'package:maps_garmin_nav/data/nav_models.dart';

class InstructionPreview extends StatelessWidget {
  const InstructionPreview({super.key, required this.instruction});

  final NavInstruction instruction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = instruction.isActive;
    return Card(
      margin: const EdgeInsets.all(Spacing.md),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          children: [
            Icon(
              instruction.maneuver.icon,
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
                        ? (active ? instruction.maneuver.label : 'No active navigation')
                        : instruction.distance,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    instruction.road.isEmpty
                        ? 'Start Google Maps navigation to preview the next turn.'
                        : instruction.road,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (instruction.instruction.isNotEmpty &&
                      instruction.instruction != instruction.road) ...[
                    const SizedBox(height: Spacing.xs),
                    Text(
                      instruction.instruction,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
