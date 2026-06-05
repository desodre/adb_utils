/// Represents a directory entry returned by the ADB SYNC LIST command.
class AdbDirEntry {
  const AdbDirEntry({
    required this.name,
    required this.mode,
    required this.size,
    required this.mtime,
  });

  /// The name of the file or directory.
  final String name;

  /// The raw file mode/permissions mask from Unix.
  final int mode;

  /// The file size in bytes.
  final int size;

  /// The last modification time.
  final DateTime mtime;

  /// Returns `true` if this entry is a directory.
  bool get isDirectory => (mode & 0xF000) == 0x4000; // S_ISDIR (0040000)

  /// Returns `true` if this entry is a regular file.
  bool get isFile => (mode & 0xF000) == 0x8000; // S_ISREG (0100000)

  /// Returns `true` if this entry is a symbolic link.
  bool get isLink => (mode & 0xF000) == 0xA000; // S_ISLNK (0120000)

  /// Returns the permission bits represented in octal format (e.g., "755").
  String get permissionsOctal => (mode & 0x1FF).toRadixString(8);

  /// Returns the permission bits in standard Unix string format (e.g., "drwxr-xr-x").
  String get permissionsString {
    final typeChar = isDirectory
        ? 'd'
        : isLink
        ? 'l'
        : '-';
    const rwx = ['---', '--x', '-w-', '-wx', 'r--', 'r-x', 'rw-', 'rwx'];
    final owner = rwx[(mode >> 6) & 0x7];
    final group = rwx[(mode >> 3) & 0x7];
    final other = rwx[mode & 0x7];
    return '$typeChar$owner$group$other';
  }

  @override
  String toString() =>
      '$permissionsString ${size.toString().padLeft(8)} ${mtime.toIso8601String()} $name';
}
