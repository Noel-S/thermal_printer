import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:thermalprinter/printer/device.dart';

import 'thermalprinter_platform_interface.dart';

/// An implementation of [ThermalprinterPlatform] that uses method channels.
class MethodChannelThermalprinter extends ThermalprinterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('thermalprinter_channel');
  final eventChannel = const EventChannel('thermalprinter');
  final _bluetoothDevicesStreamController = StreamController<List<BluetoothDevice>>.broadcast();
  final _currentBluetoothDevices = <String, BluetoothDevice>{};
  StreamSubscription? _bluetoothScanSubscription;
  // final _usbDevicesStreamController = StreamController<List<USBDevice>>();

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  ScanResult<T> scan<T>({Duration timeout = const Duration(seconds: 10)}) {
    if (T == BluetoothDevice) {
      return ScanResult<T>(
        devices: _bluetoothDevicesStreamController.stream.cast(),
        stop: _bluetoothScanSubscription?.cancel,
        start: () => _startBluetoothScan(timeout),
      )..start();
    }

    throw UnimplementedError('scan() has not been implemented.');
    // return _usbDevicesStreamController.stream;
  }

  void _startBluetoothScan(Duration timeout) {
    _currentBluetoothDevices.clear();
    _bluetoothScanSubscription?.cancel();
    _bluetoothScanSubscription = eventChannel.receiveBroadcastStream({'method': 'scan', 'timeout': timeout.inMilliseconds, 'type': 'bluetooth'}).doOnError((p0, p1) {
      _bluetoothScanSubscription?.cancel();
      log('Error: $p0, $p1');
    }).listen((event) {
      if (!_currentBluetoothDevices.containsKey(event["identifier"])) {
        _currentBluetoothDevices[event["identifier"]] = BluetoothDevice.fromMap(event);
        _bluetoothDevicesStreamController.add(_currentBluetoothDevices.values.toList());
      }
    });
  }

  @override
  Future<bool> printBluetooth(Uint8List bytes, String identifier) async {
    final result = await methodChannel.invokeMethod<bool>('printBluetooth', {'bytes': bytes, 'identifier': identifier});
    return result ?? false;
  }

  @override
  Future<bool> connectBluetooth(String identifier) async {
    final result = await methodChannel.invokeMethod<bool>('connectBluetooth', {'identifier': identifier});
    return result ?? false;
  }
}
