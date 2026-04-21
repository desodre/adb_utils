import '../exceptions.dart';

/// Information about an installed Android application.
class AppInfo {
  const AppInfo({
    required this.packageName,
    this.versionName,
    this.versionCode,
    this.firstInstallTime,
    this.lastUpdateTime,
  });

  final String packageName;
  final String? versionName;
  final int? versionCode;

  /// Device-local wall-clock time when the package was first installed.
  /// Note: no timezone info is available from `dumpsys`; the value reflects
  /// the device's local clock at the time of install.
  final DateTime? firstInstallTime;

  /// Device-local wall-clock time of the last package update.
  final DateTime? lastUpdateTime;

  /// Parses the output of `dumpsys package <packageName>` into an [AppInfo].
  ///
  /// Throws [AdbError] if the package is not found or the output cannot be
  /// parsed (missing `Package [<packageName>]` header).
  factory AppInfo.fromDumpsys(String packageName, String output) {
    if (output.contains('Unable to find package')) {
      throw AdbError('Package not found: $packageName');
    }
    if (!output.contains('Package [$packageName]')) {
      throw AdbError('Could not parse dumpsys output for: $packageName');
    }

    final versionCodeMatch = RegExp(r'versionCode=(\d+)').firstMatch(output);
    final versionCode = versionCodeMatch != null
        ? int.parse(versionCodeMatch.group(1)!)
        : null;

    final versionNameMatch = RegExp(
      r'^\s*versionName=(.*)$',
      multiLine: true,
    ).firstMatch(output);
    final versionName = versionNameMatch?.group(1)?.trim();

    // `firstInstallTime` may appear once per Android user profile.
    // Filter out epoch-sentinel values (year < 2000) and return the earliest
    // real install timestamp, which corresponds to the first user who installed
    // the package.
    final firstInstallTimes =
        RegExp(r'firstInstallTime=(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})')
            .allMatches(output)
            .map((m) => DateTime.tryParse(m.group(1)!.replaceFirst(' ', 'T')))
            .whereType<DateTime>()
            .where((dt) => dt.year >= 2000)
            .toList();
    final firstInstallTime = firstInstallTimes.isEmpty
        ? null
        : firstInstallTimes.reduce((a, b) => a.isBefore(b) ? a : b);

    final lastUpdateMatch = RegExp(
      r'lastUpdateTime=(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})',
    ).firstMatch(output);
    final lastUpdateTime = lastUpdateMatch != null
        ? DateTime.tryParse(lastUpdateMatch.group(1)!.replaceFirst(' ', 'T'))
        : null;

    return AppInfo(
      packageName: packageName,
      versionName: versionName,
      versionCode: versionCode,
      firstInstallTime: firstInstallTime,
      lastUpdateTime: lastUpdateTime,
    );
  }

  @override
  String toString() => 'AppInfo(package: $packageName, version: $versionName)';
}

/// Current foreground app info.
class ForegroundAppInfo {
  const ForegroundAppInfo({
    required this.packageName,
    required this.activity,
    this.pid,
  });

  final String packageName;
  final String activity;
  final int? pid;

  @override
  String toString() =>
      'ForegroundAppInfo(package: $packageName, activity: $activity)';
}
