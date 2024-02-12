import 'dart:async';
import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:uuid/v4.dart';

abstract class Printer {
  final String uuid;

  final PaperSize paperSize;
  final CapabilityProfile profile;
  final Generator generator;
  final StreamController<PrintJob> queue = StreamController<PrintJob>();

  Printer({required this.uuid, required this.paperSize, required this.profile, required this.generator});

  Future<bool> send(Uint8List data);
  Future<bool> isBusy();
  Future<bool> isConnected();
  Future<bool> connect();
  Future<bool> disconnect();
  Future<bool> reset();
}

class PrintJob {
  final Uint8List data;
  final String uuid = const UuidV4().generate();
  final Completer<bool> completer = Completer<bool>();

  PrintJob(this.data);
}
