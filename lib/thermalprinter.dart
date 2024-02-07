import 'dart:typed_data';

import 'package:thermalprinter/printer/device.dart';

import 'thermalprinter_platform_interface.dart';

class Thermalprinter {
  Future<String?> getPlatformVersion() {
    return ThermalprinterPlatform.instance.getPlatformVersion();
  }

  ScanResult<T> scan<T>({Duration timeout = const Duration(seconds: 10)}) {
    return ThermalprinterPlatform.instance.scan<T>(timeout: timeout);
  }

  Future<bool> printBluetooth(Uint8List bytes, String identifier) {
    return ThermalprinterPlatform.instance.printBluetooth(bytes, identifier);
  }

  Future<bool> connectBluetooth(String identifier) async {
    return ThermalprinterPlatform.instance.connectBluetooth(identifier);
  }
}
