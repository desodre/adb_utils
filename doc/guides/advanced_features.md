# Advanced Features

Practical guides for advanced workflows: Phantom H.264 streaming and HTML test report generation.

## 1) Consuming Phantom Video Stream (H.264)

```dart
import 'dart:async';
import 'package:adb_utils/adb_utils.dart';

Future<void> main() async {
  final adb = AdbClient();
  final device = await adb.device();
  final phantom = device.phantom;
  await phantom.startAgent();

  final stream = await phantom.startVideoStream();
  final sub = stream.listen(
    (chunk) => print('H264 chunk bytes: ${chunk.length}'),
    onError: (e, st) => print('Stream error: $e'),
  );

  await Future<void>.delayed(const Duration(seconds: 5));
  await sub.cancel();
}
```

### Production recommendations

1. Use a buffer or queue to decouple TCP reads from decoding.
2. Apply backpressure when the decoder is saturated.
3. Apply an inactivity watchdog to restart a frozen stream.

## 2) Automatic HTML Test Report

The project provides APIs for producing HTML reports with summaries and failure evidence.

```dart
import 'package:adb_utils/adb_utils.dart';

Future<void> main() async {
  final results = <TestResult>[
    TestResult(
      nome: 'deviceList returns connected devices',
      categoria: 'integration',
      duracao: const Duration(milliseconds: 120),
      passou: true,
    ),
    TestResult(
      nome: 'dumpWindow returns XML',
      categoria: 'phantom',
      duracao: const Duration(milliseconds: 450),
      passou: false,
      mensagemErro: 'Socket timeout',
      stackTrace: '...',
    ),
  ];

  final reporter = HtmlReporter(outputPath: 'report.html');
  await reporter.writeReport(results);
}
```

## 3) Sequential Test Execution with TestRunner

```dart
import 'package:adb_utils/adb_utils.dart';

Future<void> main() async {
  final runner = TestRunner();

  await runner.runTest('Check model property', 'adb', () async {
    final adb = AdbClient();
    final d = await adb.device();
    final model = await d.prop.model;
    if (model.trim().isEmpty) {
      throw StateError('Model is empty');
    }
  });

  await HtmlReporter(outputPath: 'report.html').writeReport(runner.resultados);
}
```

## Related

- Troubleshooting: [troubleshooting.md](troubleshooting.md)
- Protocol internals: [../architecture/protocols.md](../architecture/protocols.md)
