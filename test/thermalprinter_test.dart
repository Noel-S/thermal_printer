import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thermalprinter/printer/device.dart';
import 'package:thermalprinter/thermalprinter.dart';
import 'package:thermalprinter/thermalprinter_platform_interface.dart';
import 'package:thermalprinter/thermalprinter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockThermalprinterPlatform with MockPlatformInterfaceMixin implements ThermalprinterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<bool> connectBluetooth(String identifier) {
    // TODO: implement connectBluetooth
    throw UnimplementedError();
  }

  @override
  Future<bool> printBluetooth(Uint8List bytes, String identifier) {
    // TODO: implement printBluetooth
    throw UnimplementedError();
  }

  @override
  ScanResult<T> scan<T>({Duration timeout = const Duration(seconds: 10)}) {
    // TODO: implement scan
    throw UnimplementedError();
  }

  @override
  Future<bool> disconnectBluetooth(String identifier) {
    // TODO: implement disconnectBluetooth
    throw UnimplementedError();
  }

  @override
  // TODO: implement isBluetoothEnabled
  Future<bool> get isBluetoothEnabled => throw UnimplementedError();
}

void main() {
  final ThermalprinterPlatform initialPlatform = ThermalprinterPlatform.instance;

  test('$MethodChannelThermalprinter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelThermalprinter>());
  });

  test('getPlatformVersion', () async {
    Thermalprinter thermalprinterPlugin = Thermalprinter();
    MockThermalprinterPlatform fakePlatform = MockThermalprinterPlatform();
    ThermalprinterPlatform.instance = fakePlatform;

    expect(await thermalprinterPlugin.getPlatformVersion(), '42');
  });
}
