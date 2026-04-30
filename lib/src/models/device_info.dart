/// State reported by `adb devices`.
enum DeviceState {
  /// Device is connected and accessible.
  device,

  /// Device is connected but offline.
  offline,

  /// Device is connected but requires authorization.
  unauthorized,

  /// Device is in recovery mode.
  recovery,

  /// Unknown state.
  unknown;

  /// Parses a string into a [DeviceState].
  static DeviceState parse(String value) {
    return DeviceState.values.firstWhere(
      (s) => s.name == value,
      orElse: () => DeviceState.unknown,
    );
  }
}

/// Represents a single entry from `adb devices -l`.
class DeviceInfo {
  /// Creates a new device info object.
  const DeviceInfo({
    required this.serial,
    required this.state,
    this.transportId,
    this.product,
    this.model,
    this.device,
  });

  /// The unique serial number of the device.
  final String serial;

  /// The current state of the device connection.
  final DeviceState state;

  /// The ADB internal transport ID.
  final int? transportId;

  /// The product name.
  final String? product;

  /// The device model name.
  final String? model;

  /// The device hardware type.
  final String? device;

  @override
  String toString() => 'DeviceInfo(serial: $serial, state: ${state.name})';
}
