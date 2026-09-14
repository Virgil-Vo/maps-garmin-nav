import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light {
    const seed = Color(0xFF0B6E4F);
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seed),
      useMaterial3: true,
    );
  }
}
