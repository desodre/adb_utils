/// Dart library for interacting with ADB (Android Debug Bridge).
///
/// Quick start:
/// ```dart
/// import 'package:adb_utils/adb_utils.dart';
///
/// void main() async {
///   final adb = AdbClient();
///   final d = await adb.device();
///   final model = await d.shell('getprop ro.product.model');
///   configureAdbUtilsLogging();
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
export 'src/models/ui_hierarchy.dart';
export 'src/phantom/phantom_client.dart';
export 'src/logging/adb_logging.dart';
export 'src/reporting/html_reporter.dart';
export 'src/reporting/test_result.dart';
export 'src/reporting/test_runner.dart';
