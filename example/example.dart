import 'dart:io';

import 'package:adb_utils/adb_utils.dart';

Future<void> main() async {
  // This example demonstrates the complete "happy path" using adb_utils:
  // 1) Connect to ADB server
  // 2) Select a device
  // 3) Start Phantom agent
  // 4) Dump UI hierarchy
  // 5) Click by text
  final adb = AdbClient();

  try {
    print('[1/5] Checking ADB server version...');
    final serverVersion = await adb.serverVersion();
    print('ADB server version: $serverVersion');

    print('[2/5] Listing connected devices...');
    final devices = await adb.deviceList();
    if (devices.isEmpty) {
      print('No connected devices found. Connect a device and retry.');
      exitCode = 1;
      return;
    }

    final selected = devices.first;
    final device = await adb.device(serial: selected.serial);
    print('Using device: ${selected.serial} (${selected.model ?? 'unknown'})');

    print('[3/5] Starting Phantom agent...');
    final phantom = device.phantom;
    await phantom.startAgent();
    print('Phantom agent started and port forwarding is ready.');

    print('[4/5] Dumping UI hierarchy...');
    final hierarchy = await phantom.dumpWindowHierarchy();
    print(
      'UI hierarchy received. rotation=${hierarchy.rotation}, '
      'rootNodes=${hierarchy.nodes.length}',
    );

    print('[5/5] Performing clickByText("Entrar")...');
    final clickOk = await phantom.clickByText('Entrar');
    print('clickByText result: $clickOk');

    print('Happy path completed successfully.');
  } on AdbTimeout catch (e, st) {
    stderr.writeln('ADB timeout error: $e');
    stderr.writeln(st);
    exitCode = 2;
  } on AdbError catch (e, st) {
    stderr.writeln('ADB protocol error: $e');
    stderr.writeln(st);
    exitCode = 3;
  } catch (e, st) {
    stderr.writeln('Unexpected error: $e');
    stderr.writeln(st);
    exitCode = 99;
  }
}
