import 'package:flutter/services.dart';

class NavBridge {
  NavBridge._();

  static final NavBridge instance = NavBridge._();

  static const _methods = MethodChannel('com.mapsgarmin.nav/methods');
  static const _events = EventChannel('com.mapsgarmin.nav/events');

  Stream<Map<dynamic, dynamic>> events() {
    return _events.receiveBroadcastStream().map(
      (event) => Map<dynamic, dynamic>.from(event as Map),
    );
  }

  Future<Map<dynamic, dynamic>> getStatus() async {
    final result = await _methods.invokeMethod<dynamic>('getStatus');
    if (result is Map) {
      return Map<dynamic, dynamic>.from(result);
    }
    return <dynamic, dynamic>{};
  }

  Future<void> openNotificationListenerSettings() {
    return _methods.invokeMethod('openNotificationListenerSettings');
  }

  Future<void> openBatteryOptimizationSettings() {
    return _methods.invokeMethod('openBatteryOptimizationSettings');
  }

  Future<void> startForeground() {
    return _methods.invokeMethod('startForeground');
  }

  Future<void> setTethered(bool enabled) {
    return _methods.invokeMethod('setTethered', enabled);
  }

  Future<void> initializeGarmin() {
    return _methods.invokeMethod('initializeGarmin');
  }

  Future<void> openWatchApp() {
    return _methods.invokeMethod('openWatchApp');
  }

  Future<Map<dynamic, dynamic>> getWatchDisplaySettings() async {
    final result = await _methods.invokeMethod<dynamic>(
      'getWatchDisplaySettings',
    );
    if (result is Map) {
      return Map<dynamic, dynamic>.from(result);
    }
    return <dynamic, dynamic>{};
  }

  Future<void> setWatchDisplaySettings(Map<String, dynamic> settings) {
    return _methods.invokeMethod('setWatchDisplaySettings', settings);
  }
}
