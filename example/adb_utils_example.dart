import 'package:adb_utils/adb_utils.dart';

void main() async {
  // Inicializa o cliente apontando para o servidor ADB local padrão.
  final adb = AdbClient();

  print('Procurando dispositivos conectados...');
  final devices = await adb.deviceList();

  if (devices.isEmpty) {
    print('Nenhum dispositivo encontrado.');
    return;
  }

  // Lista os dispositivos encontrados
  for (final d in devices) {
    print(' - ${d.serial} (${d.state.name})');
  }

  // Pega uma referência ao primeiro dispositivo conectado
  final device = await adb.device();

  print('\nInformações do Dispositivo Principal:');
  // Usa o cache=true para não chamar o shell várias vezes à toa se precisar ler depois
  print(' Modelo: ${await device.prop.model}');
  print(' Marca: ${await device.prop.brand}');
  print(' Versão do Android (SDK): ${await device.prop.sdkVersion}');

  print('\nExecutando comando "uname -r" no shell:');
  final kernel = await device.shell('uname -r');
  print(' Kernel: $kernel');
}
