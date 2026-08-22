import 'dart:convert';
import 'dart:io';

const _fallbackTargetPath = 'lib/src/phantom/apks/target.apk';
const _fallbackAgentPath = 'lib/src/phantom/apks/agent.apk';
const _outputPath = 'lib/src/phantom/phantom_binaries.dart';

Future<void> main(List<String> args) async {
  final targetInput = args.isNotEmpty ? args[0] : 'target.apk';
  final agentInput = args.length > 1 ? args[1] : 'agent.apk';

  final targetFile = _resolveInput(targetInput, _fallbackTargetPath, 'target');
  final agentFile = _resolveInput(agentInput, _fallbackAgentPath, 'agent');

  final targetBase64 = base64Encode(await targetFile.readAsBytes());
  final agentBase64 = base64Encode(await agentFile.readAsBytes());

  final output = File(_outputPath);
  await output.parent.create(recursive: true);
  final generatedContent =
      '/// GENERATED FILE - DO NOT EDIT BY HAND.\n'
      '/// Run: dart run tool/generate_base64_apks.dart\n'
      '/// Matches https://github.com/desodre/phantom_agent.\n'
      '/// Regenerate this file whenever the agent APKs change.\n'
      'library;\n\n'
      "const String targetApkBase64 = r'''$targetBase64''';\n"
      "const String agentApkBase64 = r'''$agentBase64''';\n";
  await output.writeAsString(generatedContent, flush: true);

  stdout.writeln('Generated $_outputPath');
  stdout.writeln('target: ${targetFile.path}');
  stdout.writeln('agent : ${agentFile.path}');
}

File _resolveInput(String primary, String fallback, String label) {
  final primaryFile = File(primary);
  if (primaryFile.existsSync()) {
    return primaryFile;
  }

  final fallbackFile = File(fallback);
  if (fallbackFile.existsSync()) {
    return fallbackFile;
  }

  throw FileSystemException(
    'Could not find $label APK. Checked "$primary" and "$fallback".',
  );
}
