/// ADB socket network types for `create_connection`.
enum NetworkType {
  tcp,
  unix,
  localAbstract,
  localReserved,
  localFilesystem,
  dev,
  jdwp;

  /// Returns the ADB protocol prefix string for this network type.
  String get prefix => switch (this) {
        NetworkType.tcp => 'tcp',
        NetworkType.unix => 'unix',
        NetworkType.localAbstract => 'localabstract',
        NetworkType.localReserved => 'localreserved',
        NetworkType.localFilesystem => 'localfilesystem',
        NetworkType.dev => 'dev',
        NetworkType.jdwp => 'jdwp',
      };
}
