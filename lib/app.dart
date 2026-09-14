import 'package:flutter/material.dart';
import 'package:maps_garmin_nav/core/theme.dart';
import 'package:maps_garmin_nav/features/home/home_page.dart';

class MapsGarminApp extends StatelessWidget {
  const MapsGarminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maps Garmin Nav',
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maps Garmin Nav')),
      body: const HomePage(),
    );
  }
}
