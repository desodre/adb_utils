/// A single entry from `adb forward --list` or `adb reverse --list`.
class ForwardItem {
  const ForwardItem({
    required this.serial,
    required this.local,
    required this.remote,
  });

  final String serial;
  final String local;
  final String remote;

  @override
  String toString() => 'ForwardItem($serial: $local -> $remote)';
}
