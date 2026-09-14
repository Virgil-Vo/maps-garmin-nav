import 'package:flutter/material.dart';
import 'package:maps_garmin_nav/core/spacing.dart';

class PermissionTile extends StatelessWidget {
  const PermissionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final bool granted;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      leading: Icon(
        granted ? Icons.check_circle : Icons.error_outline,
        color: granted
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: granted
          ? null
          : TextButton(onPressed: onPressed, child: Text(actionLabel)),
    );
  }
}
