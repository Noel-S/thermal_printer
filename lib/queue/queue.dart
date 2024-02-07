// import 'dart:typed_data';

// import 'package:rxdart/subjects.dart';
// import 'package:thermalprinter/printer/printer.dart';
// import 'package:uuid/uuid.dart';

class Queue {
  // final Uuid _uuid = const Uuid();
  // final Map<String, Printer> _openPrinters = {};
  // final Map<String, BehaviorSubject<Uint8List>> _printQueue = {};

  // bool addPrinter(Printer printer) {
  //   if (_openPrinters.containsKey(printer.uuid)) {
  //     return false;
  //   }
  //   _openPrinters[printer.uuid] = printer;
  //   return true;
  // }

  // bool removePrinter(Printer printer) {
  //   if (!_openPrinters.containsKey(printer.uuid)) {
  //     return false;
  //   }
  //   _openPrinters.remove(printer.uuid);
  //   return true;
  // }

  // Future<bool> print(Printer printer, Uint8List data) async {
  //   if (!_openPrinters.containsKey(printer.uuid)) {
  //     _openPrinters[printer.uuid] = printer;
  //     if (!await printer.connect()) {
  //       return false;
  //     }
  //   }
  //   _printQueue[printer.uuid]?.add(data);
  //   return true;
  // }
}
