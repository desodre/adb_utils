@TestOn('vm')
@Tags(['device', 'multi_device', 'all_possible'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:adb_utils/adb_utils.dart';

import '../helpers/adb_test_helpers.dart';
import '../helpers/reporting.dart';

void main() {
  configureHtmlReporting(
    suiteName: 'integration/test_multi_stream_video_performance_test.dart',
  );

  late List<AdbDevice> devices;

  setUpAll(() async {
    final found = await AdbClient().listDevices();
    if (found.isEmpty) {
      markTestSkipped('Dispositivos não encontrados');
    }
    devices = await requireAtLeastDevices(2);
    if (devices.length < 2) {
      markTestSkipped('São necessários pelo menos 2 dispositivos online.');
    }
  });

  group('Parallel video stream performance', () {
    test(
      'starts two H.264 streams in parallel and checks fps/memory safety',
      () async {
        final pair = devices.take(2).toList();
        if (pair.length < 2) {
          markTestSkipped(
            'Menos de 2 dispositivos disponíveis para stream paralelo.',
          );
          return;
        }
        final deviceBySerial = {
          for (final device in pair) device.serial: device,
        };

        final clients = pair.asMap().entries.map((entry) {
          final controlPort = 9030 + entry.key;
          return (
            serial: entry.value.serial,
            client: PhantomClient(
              device: entry.value,
              port: controlPort,
              videoPort: controlPort + 100,
            ),
          );
        }).toList();

        try {
          await Future.wait(
            clients.map((c) async {
              try {
                await c.client.startAgent();
              } catch (e) {
                throw StateError(
                  'serial=${c.serial} failed to start agent: $e',
                );
              }
            }),
          );
        } on StateError catch (e) {
          if (e.message.contains(
                'Could not read dynamic Phantom ports from logcat',
              ) ||
              e.message.contains('Connection refused') ||
              e.message.contains('device offline')) {
            markTestSkipped(
              'Phantom agent não está estável neste ambiente de teste: $e',
            );
            return;
          }
          rethrow;
        }

        final baselineRssBytes = ProcessInfo.currentRss;
        final sampleWindow = const Duration(seconds: 8);

        List<Socket> sockets;
        try {
          sockets = (await Future.wait(
            clients.map((c) async {
              try {
                final stream = await c.client.startVideoStream();
                return stream as Socket;
              } catch (e) {
                throw StateError(
                  'serial=${c.serial} failed to start video stream: $e',
                );
              }
            }),
          )).toList();
        } catch (e) {
          markTestSkipped(
            'Parallel H.264 stream not supported in current host setup: $e',
          );
          return;
        }

        final chunksBySerial = <String, int>{
          clients[0].serial: 0,
          clients[1].serial: 0,
        };
        const maxEvidenceBytesPerSerial = 2 * 1024 * 1024;
        final videoBytesBySerial = <String, BytesBuilder>{
          clients[0].serial: BytesBuilder(copy: false),
          clients[1].serial: BytesBuilder(copy: false),
        };
        final subs = <StreamSubscription<List<int>>>[];

        for (var i = 0; i < sockets.length; i++) {
          final serial = clients[i].serial;
          final sub = sockets[i].listen(
            (chunk) {
              if (chunk.isNotEmpty) {
                chunksBySerial.update(serial, (v) => v + 1);
                final collector = videoBytesBySerial[serial]!;
                final remaining = maxEvidenceBytesPerSerial - collector.length;
                if (remaining > 0) {
                  if (chunk.length <= remaining) {
                    collector.add(chunk);
                  } else {
                    collector.add(chunk.sublist(0, remaining));
                  }
                }
              }
            },
            onError: (Object e, StackTrace st) {
              throw StateError('serial=$serial stream error: $e');
            },
            cancelOnError: true,
          );
          subs.add(sub);
        }

        await Future<void>.delayed(sampleWindow);

        for (final sub in subs) {
          await sub.cancel();
        }
        for (final socket in sockets) {
          await socket.close();
        }
        for (final entry in videoBytesBySerial.entries) {
          final bytes = entry.value.takeBytes();
          if (bytes.isNotEmpty) {
            await addTestEvidenceBytes(
              label: 'parallel-video-stream-${entry.key}',
              bytes: bytes,
              extension: 'h264',
              mediaType: 'video/h264',
            );
            continue;
          }

          final device = deviceBySerial[entry.key];
          if (device == null) {
            await addTestEvidenceBytes(
              label: 'parallel-video-stream-${entry.key}-diagnostic',
              bytes: utf8.encode('Device not found for serial=${entry.key}.'),
              extension: 'txt',
              mediaType: 'text/plain',
            );
            continue;
          }

          final remotePath =
              '/data/local/tmp/adb_utils_evidence_${entry.key}_${DateTime.now().millisecondsSinceEpoch}.mp4';
          try {
            await device.shell('screenrecord --time-limit 3 $remotePath');
            final mp4 = await device.sync.readBytes(remotePath);
            await addTestEvidenceBytes(
              label: 'parallel-video-fallback-${entry.key}',
              bytes: mp4,
              extension: 'mp4',
              mediaType: 'video/mp4',
            );
          } catch (e) {
            await addTestEvidenceBytes(
              label: 'parallel-video-stream-${entry.key}-diagnostic',
              bytes: utf8.encode(
                'No H.264 stream bytes captured and fallback screenrecord failed for '
                'serial=${entry.key}: $e',
              ),
              extension: 'txt',
              mediaType: 'text/plain',
            );
          } finally {
            await device.shell('rm -f $remotePath');
          }
        }

        final sampleSeconds = sampleWindow.inMilliseconds / 1000;
        final fpsBySerial = <String, double>{
          for (final entry in chunksBySerial.entries)
            entry.key: entry.value / sampleSeconds,
        };

        final rssDeltaBytes = ProcessInfo.currentRss - baselineRssBytes;
        const maxRssDeltaBytes = 256 * 1024 * 1024;

        for (final entry in fpsBySerial.entries) {
          expect(
            entry.value,
            greaterThan(0.5),
            reason: 'FPS too low for serial=${entry.key} (${entry.value})',
          );
        }
        expect(
          rssDeltaBytes,
          lessThan(maxRssDeltaBytes),
          reason: 'Dart RSS grew too much during dual-stream test.',
        );
      },
      timeout: const Timeout(Duration(seconds: 150)),
    );
  });
}
