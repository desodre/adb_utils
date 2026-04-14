/// Dart library for interacting with ADB (Android Debug Bridge).
///
/// Quick start:
/// ```dart
/// import 'package:adb_utils/adb_utils.dart';
///
/// void main() async {
///   final adb = AdbClient();
///   final d = await adb.device();
///   print(await d.shell('getprop ro.product.model'));
/// }
/// ```
library;

export 'src/adb_client.dart';
export 'src/adb_device.dart';
export 'src/adb_sync.dart';
export 'src/exceptions.dart';
export 'src/models/app_info.dart';
export 'src/models/device_info.dart';
export 'src/models/forward_item.dart';
export 'src/models/network_type.dart';
export 'src/models/shell_result.dart';

