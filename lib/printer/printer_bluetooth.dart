import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:thermalprinter/printer/printer.dart';
import 'package:thermalprinter/thermalprinter.dart';

class BluetoothPrinter extends Printer {
  String identifier;
  bool _isPrinting = false;
  BluetoothPrinter._internal({required this.identifier, required super.paperSize, required super.profile, required super.uuid, required super.generator, super.protocol}) {
    queue.stream.listen((job) async {
      _isPrinting = true;
      // perform print
      final result = await Thermalprinter().printBluetooth(job.data, identifier, protocol: protocol);
      _printQueue.removeAt(0);
      await Future.delayed(const Duration(milliseconds: 500));
      job.completer.complete(result);
      _isPrinting = false;
      if (_printQueue.isNotEmpty) {
        queue.add(_printQueue[0]);
      } else {
        // await disconnect();
      }
    });
  }

  factory BluetoothPrinter({required String identifier, required PaperSize paperSize, required CapabilityProfile profile, int spaceBetweenRows = 5, String protocol = 'escpos'}) {
    return BluetoothPrinter._internal(
      identifier: identifier,
      paperSize: paperSize,
      profile: profile,
      uuid: identifier,
      protocol: protocol,
      generator: Generator(paperSize, profile, spaceBetweenRows: spaceBetweenRows),
    );
  }

  final List<PrintJob> _printQueue = [];

  @override
  Future<bool> send(Uint8List data) async {
    final job = PrintJob(data);
    _printQueue.add(job);
    if (!_isPrinting) {
      queue.add(job);
    }
    return job.completer.future;
  }

  @override
  Future<bool> connect() {
    return Thermalprinter().connectBluetooth(identifier);
  }

  @override
  Future<bool> disconnect() {
    return Thermalprinter().disconnectBluetooth(identifier);
  }

  @override
  Future<bool> isBusy() async => _isPrinting;

  @override
  Future<bool> isConnected() async => true;

  @override
  Future<bool> reset() async => true;
}
