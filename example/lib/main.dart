import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:thermalprinter/printer/device.dart';
import 'package:thermalprinter/thermalprinter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _thermalprinterPlugin = Thermalprinter();

  @override
  void initState() {
    _requestPermission();
    super.initState();
  }

  void _requestPermission() async {
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothAdvertise.request();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Thermalprinter example'),
        ),
        body: StreamBuilder<List<BluetoothDevice>>(
          stream: _thermalprinterPlugin.scan<BluetoothDevice>().devices,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            switch (snapshot.connectionState) {
              case ConnectionState.none:
                return const Text('None');
              case ConnectionState.waiting:
                return const Text('Waiting');
              case ConnectionState.active:
                return ListView.builder(
                  itemCount: snapshot.data?.length ?? 0,
                  itemBuilder: (context, index) {
                    final device = snapshot.data![index];
                    return ListTile(
                      title: Text(device.name),
                      subtitle: Text(device.identifier),
                    );
                  },
                );
              case ConnectionState.done:
                return const Text('Done');
            }
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            _thermalprinterPlugin.scan<BluetoothDevice>().start();
          },
          label: const Text('Scan'),
        ),
      ),
    );
  }
}
