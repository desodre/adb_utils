/// State reported by `adb devices`.
enum DeviceState {
  device,
  offline,
  unauthorized,
  recovery,
  unknown;

  static DeviceState parse(String value) {
    return DeviceState.values.firstWhere(
      (s) => s.name == value,
      orElse: () => DeviceState.unknown,
    );
  }
}

/// Represents a single entry from `adb devices -l`.
class DeviceInfo {
  const DeviceInfo({
    required this.serial,
    required this.state,
    this.transportId,
    this.product,
    this.model,
    this.device,
  });

  final String serial;
  final DeviceState state;
  final int? transportId;
  final String? product;
  final String? model;
  final String? device;

  @override
  String toString() => 'DeviceInfo(serial: $serial, state: ${state.name})';
}
