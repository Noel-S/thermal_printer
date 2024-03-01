import Flutter
import UIKit
import CoreBluetooth

public class ThermalprinterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, CBCentralManagerDelegate, CBPeripheralDelegate {
    let serviceUUID = CBUUID(string: "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2")
    let characteristicCBUUID = CBUUID(string: "BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F")
    var centralManager: CBCentralManager?
    var printerPeripheral: CBPeripheral?
    var bytes: [UInt8] = []
    var scanSink: FlutterEventSink?
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            case .unknown:
                print("central.state is .unknown")
            case .resetting:
                print("central.state is .resetting")
            case .unsupported:
                print("central.state is .unsupported")
            case .unauthorized:
                print("central.state is .unauthorized")
            case .poweredOff:
                print("central.state is .poweredOff")
            case .poweredOn:
                print("central.state is .poweredOn")
            @unknown default:
                print("central.state is unknown")
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
          if peripheral.name != nil {
              // print(advertisementData)
              let device = [
                "name": peripheral.name ?? "No name",
                "identifier": peripheral.identifier.uuidString,
                "type": "iOS"
              ] as [String : Any]
              scanSink?(device)
          }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        let service: CBService = services.first!
        peripheral.discoverCharacteristics([characteristicCBUUID], for: service)
    }
      
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        let characteristic: CBCharacteristic = characteristics.first!
        let data = Data(_: bytes)
          Thread(block: {
              peripheral.writeValue(data, for: characteristic, type: CBCharacteristicWriteType.withResponse)
              DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                  if (peripheral.state != .disconnected) {
                      self.centralManager?.cancelPeripheralConnection(peripheral)
                  }
              }
          }).start()
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        let args: Dictionary<String, Any> = arguments as! Dictionary<String, Any>
        if args["method"] as! String == "scan" {
            scanSink = events
            self._scanBluetooth(time: args["timeout"] as! Int)
        }
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        scanSink?(FlutterEndOfEventStream)
        scanSink = nil
        return nil
    }
    
    func _printBluetooth(identifier: String, data:[UInt8], result: FlutterResult) {
        bytes = data
        if centralManager == nil {
            result(false)
            return
        }
        printerPeripheral = centralManager!.retrievePeripherals(withIdentifiers: [UUID(uuidString: identifier)!]).first
        if printerPeripheral == nil {
            result(false)
            return
        }
        
        printerPeripheral!.delegate = self
        centralManager!.connect(printerPeripheral!)
        result(true)
    }
        
    func _isEnabled(result: FlutterResult) {
        result(centralManager?.state == .poweredOn)
    }
    
    func _scanBluetooth(time: Int) {
        if centralManager == nil {
            return
        }
        if centralManager!.state != .poweredOn {
            return
        }
        centralManager!.scanForPeripherals(withServices: [serviceUUID])
        DispatchQueue.main.asyncAfter(deadline: .now() + (Double(time)/1000.0)) {
            self.centralManager!.stopScan()
            self.scanSink?(FlutterEndOfEventStream)
            self.scanSink = nil
        }
    }
    
//    init(centralManager: CBCentralManager? = nil, printerPeripheral: CBPeripheral? = nil, bytes: [UInt8] = [], scanSink: FlutterEventSink? = nil) {
//        self.centralManager = CBCentralManager(delegate: self, queue: nil)
//        self.printerPeripheral = printerPeripheral
//        self.bytes = bytes
//        self.scanSink = scanSink
//    }
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "thermalprinter_channel", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "thermalprinter", binaryMessenger: registrar.messenger())
        let instance = ThermalprinterPlugin()
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args: Dictionary<String, Any>? = call.arguments as? Dictionary<String, Any>
        switch call.method {
            case "status":
                self._isEnabled(result: result)
            case "printBluetooth":
                let data = args?["bytes"] as! NSMutableArray
                self._printBluetooth(identifier: args?["identifier"] as! String, data: data.map { $0 as! UInt8 }, result: result)
//            case "connectBluetooth":
//                if let identifier = call.argument<String>("identifier") {
//                    connectBluetooth(identifier, result)
//                }
//            case "disconnectBluetooth":
//                if let identifier = call.argument<String>("identifier") {
//                    disconnectBluetooth(identifier, result)
//                }
            default:
              result(FlutterMethodNotImplemented)
        }
    }
}
