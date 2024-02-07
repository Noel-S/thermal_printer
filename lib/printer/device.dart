class USBDevice extends Device {
  int vendorId;
  int productId;
  String serialNumber;
  String manufacturer;
  String macAddress;

  USBDevice({required this.vendorId, required this.productId, required this.serialNumber, required this.manufacturer, required String name, required this.macAddress, required String address}) : super(name: name);
}

class BluetoothDevice extends Device {
  final String identifier;
  final dynamic type;

  @override
  factory BluetoothDevice.fromMap(Map map) {
    return BluetoothDevice(name: map["name"], identifier: map["identifier"], type: map["type"]);
  }

  BluetoothDevice({required super.name, required this.identifier, required this.type});
}

sealed class Device {
  final String name;

  Device({required this.name});

  factory Device.fromMap(Map<String, dynamic> map) {
    throw UnimplementedError();
  }

  bool connect() {
    throw UnimplementedError();
  }
}

class ScanResult<T> {
  final Stream<List<T>> devices;
  final void Function()? stop;
  final void Function() start;

  ScanResult({required this.devices, required this.stop, required this.start});
}
