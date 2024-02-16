import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:thermalprinter/printer/device.dart';

import 'thermalprinter_method_channel.dart';

abstract class ThermalprinterPlatform extends PlatformInterface {
  /// Constructs a ThermalprinterPlatform.
  ThermalprinterPlatform() : super(token: _token);

  static final Object _token = Object();

  static ThermalprinterPlatform _instance = MethodChannelThermalprinter();

  /// The default instance of [ThermalprinterPlatform] to use.
  ///
  /// Defaults to [MethodChannelThermalprinter].
  static ThermalprinterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ThermalprinterPlatform] when
  /// they register themselves.
  static set instance(ThermalprinterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  ScanResult<T> scan<T>({Duration timeout = const Duration(seconds: 10)}) {
    assert(timeout.inSeconds > 0);
    // assert(type != PrinterType.network, 'Network printer is not supported by scan method.');
    assert(T == BluetoothDevice || T == USBDevice, 'Invalid type for scan method.');
    throw UnimplementedError('scan() has not been implemented.');
  }

  Future<bool> printBluetooth(Uint8List bytes, String identifier) {
    throw UnimplementedError('printBluetooth() has not been implemented.');
  }

  Future<bool> connectBluetooth(String identifier) {
    throw UnimplementedError('connectBluetooth() has not been implemented.');
  }

  Future<bool> disconnectBluetooth(String identifier) {
    throw UnimplementedError('connectBluetooth() has not been implemented.');
  }

  Future<bool> get isBluetoothEnabled {
    throw UnimplementedError('isBluetoothEnabled() has not been implemented.');
  }
}
