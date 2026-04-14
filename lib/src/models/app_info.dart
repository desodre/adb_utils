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
  final DateTime? firstInstallTime;
  final DateTime? lastUpdateTime;

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
