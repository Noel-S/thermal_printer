import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:thermalprinter/printer/printer.dart';

class NetworkPrinter extends Printer {
  String host;
  int port;
  Socket? socket;
  NetworkPrinter.required({required this.host, required this.port, required super.paperSize, required super.profile, required super.uuid, required super.generator}) {
    queue.stream.listen((data) async {
      if (socket == null) {
        return;
      }
      socket?.add(data);
      await socket?.flush();
      _printQueue.removeAt(0);
      if (_printQueue.isNotEmpty) {
        queue.add(_printQueue[0]);
      } else {
        await disconnect();
      }
    });
  }

  factory NetworkPrinter({required String host, int port = 9100, required PaperSize paperSize, required CapabilityProfile profile, int spaceBetweenRows = 5}) {
    return NetworkPrinter.required(
      host: host,
      port: port,
      paperSize: paperSize,
      profile: profile,
      uuid: host,
      generator: Generator(paperSize, profile, spaceBetweenRows: spaceBetweenRows),
    );
  }

  final List<Uint8List> _printQueue = [];
  @override
  Future<bool> send(Uint8List data) async {
    if (socket == null) {
      return false;
    }
    _printQueue.add(data);
    if (_printQueue.length == 1) {
      queue.add(data);
    }
    return true;
  }

  @override
  Future<bool> connect() async {
    try {
      socket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> disconnect() async {
    socket?.close();
    socket = null;
    return true;
  }

  @override
  Future<bool> isBusy() {
    // TODO: implement isConnected
    throw UnimplementedError();
  }

  @override
  Future<bool> isConnected() {
    return Future.value(socket != null);
  }

  @override
  Future<bool> reset() {
    // TODO: implement isConnected
    throw UnimplementedError();
  }
}
