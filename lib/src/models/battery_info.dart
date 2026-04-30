/// Represents the current battery status of the device.
enum BatteryStatus {
  unknown(1),
  charging(2),
  discharging(3),
  notCharging(4),
  full(5);

  const BatteryStatus(this.value);
  final int value;

  static BatteryStatus fromValue(int value) {
    return BatteryStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BatteryStatus.unknown,
    );
  }
}

/// Contains information about the device's battery.
class BatteryInfo {
  const BatteryInfo({
    required this.level,
    required this.temperature,
    required this.status,
    required this.usbPowered,
    required this.acPowered,
  });

  /// Battery level percentage (0-100).
  final int level;

  /// Battery temperature in Celsius.
  final double temperature;

  /// Current charging status.
  final BatteryStatus status;

  /// Whether the device is currently powered via USB.
  final bool usbPowered;

  /// Whether the device is currently powered via AC charger.
  final bool acPowered;

  /// Parses the output of `adb shell dumpsys battery` into a [BatteryInfo] object.
  factory BatteryInfo.fromDumpsys(String output) {
    int level = 0;
    double temperature = 0.0;
    BatteryStatus status = BatteryStatus.unknown;
    bool usbPowered = false;
    bool acPowered = false;

    for (final line in output.split('\n')) {
      final parts = line.split(':');
      if (parts.length != 2) continue;

      final key = parts[0].trim();
      final value = parts[1].trim();

      switch (key) {
        case 'level':
          level = int.tryParse(value) ?? 0;
        case 'temperature':
          // Temperature is usually in tenths of a degree Celsius
          temperature = (int.tryParse(value) ?? 0) / 10.0;
        case 'status':
          status = BatteryStatus.fromValue(int.tryParse(value) ?? 1);
        case 'USB powered':
          usbPowered = value == 'true';
        case 'AC powered':
          acPowered = value == 'true';
      }
    }

    return BatteryInfo(
      level: level,
      temperature: temperature,
      status: status,
      usbPowered: usbPowered,
      acPowered: acPowered,
    );
  }

  @override
  String toString() =>
      'BatteryInfo(level: $level%, temp: $temperature°C, status: ${status.name}, usbPowered: $usbPowered, acPowered: $acPowered)';
}
