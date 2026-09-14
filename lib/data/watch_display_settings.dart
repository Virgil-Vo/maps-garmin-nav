class WatchDisplaySettings {
  const WatchDisplaySettings({
    this.showManeuverIcon = true,
    this.showDistance = true,
    this.showStreetName = true,
    this.showArrivalTime = false,
    this.textScale = WatchDisplayScale.normal,
    this.iconScale = WatchDisplayScale.normal,
  });

  factory WatchDisplaySettings.fromMap(Map<dynamic, dynamic> map) {
    return WatchDisplaySettings(
      showManeuverIcon: map['showManeuverIcon'] == true,
      showDistance: map['showDistance'] != false,
      showStreetName: map['showStreetName'] != false,
      showArrivalTime: map['showArrivalTime'] == true,
      textScale: WatchDisplayScale.fromValue(map['textScale']),
      iconScale: WatchDisplayScale.fromValue(map['iconScale']),
    );
  }

  final bool showManeuverIcon;
  final bool showDistance;
  final bool showStreetName;
  final bool showArrivalTime;
  final WatchDisplayScale textScale;
  final WatchDisplayScale iconScale;

  Map<String, dynamic> toMap() {
    return {
      'showManeuverIcon': showManeuverIcon,
      'showDistance': showDistance,
      'showStreetName': showStreetName,
      'showArrivalTime': showArrivalTime,
      'textScale': textScale.value,
      'iconScale': iconScale.value,
    };
  }

  WatchDisplaySettings copyWith({
    bool? showManeuverIcon,
    bool? showDistance,
    bool? showStreetName,
    bool? showArrivalTime,
    WatchDisplayScale? textScale,
    WatchDisplayScale? iconScale,
  }) {
    return WatchDisplaySettings(
      showManeuverIcon: showManeuverIcon ?? this.showManeuverIcon,
      showDistance: showDistance ?? this.showDistance,
      showStreetName: showStreetName ?? this.showStreetName,
      showArrivalTime: showArrivalTime ?? this.showArrivalTime,
      textScale: textScale ?? this.textScale,
      iconScale: iconScale ?? this.iconScale,
    );
  }
}

enum WatchDisplayScale {
  compact(0),
  normal(1),
  large(2);

  const WatchDisplayScale(this.value);

  final int value;

  static WatchDisplayScale fromValue(Object? raw) {
    final index = raw is int ? raw : int.tryParse('$raw') ?? 1;
    return WatchDisplayScale.values.firstWhere(
      (scale) => scale.value == index,
      orElse: () => WatchDisplayScale.normal,
    );
  }

  String get label {
    return switch (this) {
      WatchDisplayScale.compact => 'Compact',
      WatchDisplayScale.normal => 'Normal',
      WatchDisplayScale.large => 'Large',
    };
  }
}
