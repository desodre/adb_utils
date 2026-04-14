import 'package:adb_utils/adb_utils.dart';
import 'package:test/test.dart';

void main() {
  group('DeviceState', () {
    test('parses known states', () {
      expect(DeviceState.parse('device'), DeviceState.device);
      expect(DeviceState.parse('offline'), DeviceState.offline);
      expect(DeviceState.parse('unauthorized'), DeviceState.unauthorized);
    });

    test('parse unknown returns unknown', () {
      expect(DeviceState.parse('bogus'), DeviceState.unknown);
    });
  });

  group('ShellResult', () {
    test('isSuccess when returnCode is 0', () {
      const r = ShellResult(command: 'echo hi', returnCode: 0, output: 'hi\n');
      expect(r.isSuccess, isTrue);
    });

    test('isSuccess false when non-zero returnCode', () {
      const r = ShellResult(command: 'false', returnCode: 1, output: '');
      expect(r.isSuccess, isFalse);
    });
  });

  group('NetworkType', () {
    test('prefix values', () {
      expect(NetworkType.tcp.prefix, 'tcp');
      expect(NetworkType.localAbstract.prefix, 'localabstract');
      expect(NetworkType.dev.prefix, 'dev');
    });
  });

  group('ForwardItem', () {
    test('toString', () {
      const item = ForwardItem(
        serial: 'abc123',
        local: 'tcp:9999',
        remote: 'localabstract:scrcpy',
      );
      expect(item.toString(), contains('abc123'));
    });
  });
}
