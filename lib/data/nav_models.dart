import 'package:flutter/material.dart';

enum NavStatus { idle, navigating, rerouting, ended }

enum Maneuver {
  unknown,
  continueStraight,
  left,
  right,
  slightLeft,
  slightRight,
  sharpLeft,
  sharpRight,
  uTurn,
  roundabout,
  merge,
  arrive,
  depart,
  keepLeft,
  keepRight,
}

extension ManeuverVisual on Maneuver {
  IconData get icon {
    return switch (this) {
      Maneuver.left || Maneuver.sharpLeft => Icons.turn_left,
      Maneuver.right || Maneuver.sharpRight => Icons.turn_right,
      Maneuver.slightLeft || Maneuver.keepLeft => Icons.turn_slight_left,
      Maneuver.slightRight || Maneuver.keepRight => Icons.turn_slight_right,
      Maneuver.uTurn => Icons.u_turn_left,
      Maneuver.roundabout => Icons.roundabout_left,
      Maneuver.merge => Icons.merge,
      Maneuver.arrive => Icons.flag,
      Maneuver.depart => Icons.south,
      Maneuver.continueStraight => Icons.arrow_upward,
      Maneuver.unknown => Icons.navigation,
    };
  }

  String get label {
    return switch (this) {
      Maneuver.left => 'Left',
      Maneuver.right => 'Right',
      Maneuver.slightLeft => 'Slight left',
      Maneuver.slightRight => 'Slight right',
      Maneuver.sharpLeft => 'Sharp left',
      Maneuver.sharpRight => 'Sharp right',
      Maneuver.uTurn => 'U-turn',
      Maneuver.roundabout => 'Roundabout',
      Maneuver.merge => 'Merge',
      Maneuver.arrive => 'Arrive',
      Maneuver.depart => 'Depart',
      Maneuver.keepLeft => 'Keep left',
      Maneuver.keepRight => 'Keep right',
      Maneuver.continueStraight => 'Continue',
      Maneuver.unknown => 'Unknown',
    };
  }
}

class NavInstruction {
  const NavInstruction({
    required this.status,
    required this.maneuver,
    required this.distance,
    required this.road,
    required this.instruction,
  });

  factory NavInstruction.fromMap(Map<dynamic, dynamic> map) {
    return NavInstruction(
      status: NavStatus.values[_clampIndex(map['s'], NavStatus.values.length)],
      maneuver: Maneuver.values[_clampIndex(map['m'], Maneuver.values.length)],
      distance: (map['d'] as String?) ?? '',
      road: (map['r'] as String?) ?? '',
      instruction: (map['i'] as String?) ?? '',
    );
  }

  final NavStatus status;
  final Maneuver maneuver;
  final String distance;
  final String road;
  final String instruction;

  bool get isActive =>
      status == NavStatus.navigating || status == NavStatus.rerouting;
}

class GarminLinkStatus {
  const GarminLinkStatus({
    this.sdkReady = false,
    this.garminConnectInstalled = false,
    this.deviceName,
    this.deviceConnected = false,
    this.appInstalled = false,
    this.lastError,
  });

  factory GarminLinkStatus.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const GarminLinkStatus();
    }
    return GarminLinkStatus(
      sdkReady: map['sdkReady'] == true,
      garminConnectInstalled: map['garminConnectInstalled'] == true,
      deviceName: map['deviceName'] as String?,
      deviceConnected: map['deviceConnected'] == true,
      appInstalled: map['appInstalled'] == true,
      lastError: map['lastError'] as String?,
    );
  }

  final bool sdkReady;
  final bool garminConnectInstalled;
  final String? deviceName;
  final bool deviceConnected;
  final bool appInstalled;
  final String? lastError;
}

class CompanionStatus {
  const CompanionStatus({
    required this.notificationListenerEnabled,
    required this.batteryUnrestricted,
    required this.notificationsAllowed,
    required this.bluetoothAllowed,
    required this.garmin,
    required this.instruction,
  });

  factory CompanionStatus.initial() {
    return const CompanionStatus(
      notificationListenerEnabled: false,
      batteryUnrestricted: false,
      notificationsAllowed: false,
      bluetoothAllowed: false,
      garmin: GarminLinkStatus(),
      instruction: NavInstruction(
        status: NavStatus.idle,
        maneuver: Maneuver.unknown,
        distance: '',
        road: '',
        instruction: '',
      ),
    );
  }

  final bool notificationListenerEnabled;
  final bool batteryUnrestricted;
  final bool notificationsAllowed;
  final bool bluetoothAllowed;
  final GarminLinkStatus garmin;
  final NavInstruction instruction;

  CompanionStatus copyWith({
    bool? notificationListenerEnabled,
    bool? batteryUnrestricted,
    bool? notificationsAllowed,
    bool? bluetoothAllowed,
    GarminLinkStatus? garmin,
    NavInstruction? instruction,
  }) {
    return CompanionStatus(
      notificationListenerEnabled:
          notificationListenerEnabled ?? this.notificationListenerEnabled,
      batteryUnrestricted: batteryUnrestricted ?? this.batteryUnrestricted,
      notificationsAllowed: notificationsAllowed ?? this.notificationsAllowed,
      bluetoothAllowed: bluetoothAllowed ?? this.bluetoothAllowed,
      garmin: garmin ?? this.garmin,
      instruction: instruction ?? this.instruction,
    );
  }
}

int _clampIndex(Object? value, int length) {
  final index = value is int ? value : int.tryParse('$value') ?? 0;
  if (index < 0 || index >= length) {
    return 0;
  }
  return index;
}
