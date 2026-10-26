import Flutter
import UIKit
import CoreBluetooth

/// A single print request for one printer, from connection to the last written byte.
private final class PrintJob {
    let identifier: UUID
    let data: Data
    let result: FlutterResult
    var peripheral: CBPeripheral?
    var characteristic: CBCharacteristic?
    var writeType: CBCharacteristicWriteType = .withResponse
    var chunkSize = 20
    var offset = 0
    var connected = false
    var searching = false
    var pendingServices = 0
    var timeout: DispatchWorkItem?

    init(identifier: UUID, data: Data, result: @escaping FlutterResult) {
        self.identifier = identifier
        self.data = data
        self.result = result
    }
}

public class ThermalprinterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, CBCentralManagerDelegate, CBPeripheralDelegate {
    /// Write characteristics used by common thermal printers, preferred over any other writable one.
    private let preferredCharacteristics: [CBUUID] = [
        CBUUID(string: "BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F"),
        CBUUID(string: "49535343-8841-43F4-A8D4-ECBE34729BB3"),
        CBUUID(string: "2AF1"),
        CBUUID(string: "FFE1"),
        CBUUID(string: "FF02"),
    ]
    var centralManager: CBCentralManager?
    var scanSink: FlutterEventSink?
    private var isUserScanning = false
    /// Job being printed per printer.
    private var activeJobs: [UUID: PrintJob] = [:]
    /// Jobs waiting for the active job of the same printer to finish.
    private var queuedJobs: [UUID: [PrintJob]] = [:]
    /// Jobs started before Bluetooth was powered on.
    private var jobsWaitingForPower: [PrintJob] = []

    // MARK: - Central

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            case .poweredOn:
                let waiting = jobsWaitingForPower
                jobsWaitingForPower.removeAll()
                waiting.forEach { connect($0) }
            case .unknown, .resetting:
                break
            default:
                // powered off, unauthorized or unsupported: nothing in progress can finish
                activeJobs.values.forEach { finish($0, success: false) }
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if isUserScanning, peripheral.name != nil {
            let device = [
                "name": peripheral.name ?? "No name",
                "identifier": peripheral.identifier.uuidString,
                "type": "iOS"
            ] as [String : Any]
            scanSink?(device)
        }
        if let job = activeJobs[peripheral.identifier], job.searching {
            job.searching = false
            stopScanIfIdle()
            job.peripheral = peripheral
            peripheral.delegate = self
            central.connect(peripheral)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let job = activeJobs[peripheral.identifier] else { return }
        job.connected = true
        peripheral.discoverServices(nil)
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard let job = activeJobs[peripheral.identifier] else { return }
        finish(job, success: false)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // ignore disconnections of a previous job while the next one is still connecting
        guard let job = activeJobs[peripheral.identifier], job.connected else { return }
        finish(job, success: false)
    }

    // MARK: - Peripheral

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let job = activeJobs[peripheral.identifier] else { return }
        guard error == nil, let services = peripheral.services, !services.isEmpty else {
            finish(job, success: false)
            return
        }
        job.pendingServices = services.count
        services.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let job = activeJobs[peripheral.identifier] else { return }
        job.pendingServices -= 1
        guard job.pendingServices == 0 else { return }

        let characteristics = (peripheral.services ?? []).flatMap { $0.characteristics ?? [] }
        let writable = characteristics.filter { $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse) }
        guard let characteristic = writable.first(where: { preferredCharacteristics.contains($0.uuid) }) ?? writable.first else {
            finish(job, success: false)
            return
        }
        job.characteristic = characteristic
        job.writeType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        // MTU-sized chunks, writes over 512 bytes fail and long writes aren't supported by many printers
        job.chunkSize = max(20, min(peripheral.maximumWriteValueLength(for: .withoutResponse), 512))
        writeNext(job)
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let job = activeJobs[peripheral.identifier], job.writeType == .withResponse else { return }
        if error != nil {
            finish(job, success: false)
            return
        }
        writeNext(job)
    }

    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        guard let job = activeJobs[peripheral.identifier], job.writeType == .withoutResponse else { return }
        writeNext(job)
    }

    // MARK: - Printing

    func _printBluetooth(identifier: String, data: [UInt8], result: @escaping FlutterResult) {
        guard let uuid = UUID(uuidString: identifier) else {
            result(false)
            return
        }
        let job = PrintJob(identifier: uuid, data: Data(data), result: result)
        if activeJobs[uuid] != nil {
            queuedJobs[uuid, default: []].append(job)
            return
        }
        start(job)
    }

    private func start(_ job: PrintJob) {
        activeJobs[job.identifier] = job
        let timeout = DispatchWorkItem { [weak self, weak job] in
            guard let self = self, let job = job else { return }
            self.finish(job, success: false)
        }
        job.timeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0 + Double(job.data.count) / 1000.0, execute: timeout)

        guard let central = centralManager else {
            finish(job, success: false)
            return
        }
        switch central.state {
            case .poweredOn:
                connect(job)
            case .unknown, .resetting:
                jobsWaitingForPower.append(job)
            default:
                finish(job, success: false)
        }
    }

    private func connect(_ job: PrintJob) {
        guard let central = centralManager else {
            finish(job, success: false)
            return
        }
        if let peripheral = central.retrievePeripherals(withIdentifiers: [job.identifier]).first {
            job.peripheral = peripheral
            peripheral.delegate = self
            central.connect(peripheral)
            return
        }
        // CoreBluetooth doesn't know this printer yet, look for it until the job times out
        job.searching = true
        if !central.isScanning {
            central.scanForPeripherals(withServices: nil)
        }
    }

    private func writeNext(_ job: PrintJob) {
        guard let peripheral = job.peripheral, let characteristic = job.characteristic else { return }
        guard job.offset < job.data.count else {
            // give the printer time to drain its buffer before disconnecting
            let delay = job.writeType == .withResponse ? 0.5 : 1.5
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak job] in
                guard let self = self, let job = job else { return }
                self.finish(job, success: true)
            }
            return
        }
        if job.writeType == .withoutResponse && !peripheral.canSendWriteWithoutResponse {
            return // resumed from peripheralIsReady(toSendWriteWithoutResponse:)
        }
        let end = min(job.offset + job.chunkSize, job.data.count)
        peripheral.writeValue(job.data.subdata(in: job.offset..<end), for: characteristic, type: job.writeType)
        job.offset = end
        if job.writeType == .withoutResponse {
            // pace writes so cheap printers don't overflow their buffer
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self, weak job] in
                guard let self = self, let job = job else { return }
                self.writeNext(job)
            }
        }
    }

    private func finish(_ job: PrintJob, success: Bool) {
        guard activeJobs[job.identifier] === job else { return }
        activeJobs.removeValue(forKey: job.identifier)
        jobsWaitingForPower.removeAll { $0 === job }
        job.timeout?.cancel()
        if let peripheral = job.peripheral, peripheral.state != .disconnected, centralManager?.state == .poweredOn {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        stopScanIfIdle()
        job.result(success)

        guard var queue = queuedJobs[job.identifier], !queue.isEmpty else { return }
        let next = queue.removeFirst()
        queuedJobs[job.identifier] = queue.isEmpty ? nil : queue
        // let the previous connection close before reconnecting to the same printer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.start(next)
        }
    }

    private func stopScanIfIdle() {
        guard let central = centralManager, central.isScanning else { return }
        if isUserScanning || activeJobs.values.contains(where: { $0.searching }) { return }
        central.stopScan()
    }

    // MARK: - Scan

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        guard let args = arguments as? [String: Any] else { return nil }
        if args["method"] as? String == "scan" {
            scanSink = events
            self._scanBluetooth(time: args["timeout"] as? Int ?? 10000)
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        scanSink?(FlutterEndOfEventStream)
        scanSink = nil
        isUserScanning = false
        stopScanIfIdle()
        return nil
    }

    func _isEnabled(result: FlutterResult) {
        result(centralManager?.state == .poweredOn)
    }

    func _scanBluetooth(time: Int) {
        guard let central = centralManager, central.state == .poweredOn else { return }
        isUserScanning = true
        if !central.isScanning {
            central.scanForPeripherals(withServices: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (Double(time)/1000.0)) {
            self.isUserScanning = false
            self.stopScanIfIdle()
            self.scanSink?(FlutterEndOfEventStream)
            self.scanSink = nil
        }
    }

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
        let args = call.arguments as? [String: Any]
        switch call.method {
            case "status":
                self._isEnabled(result: result)
            case "printBluetooth":
                if let data = args?["bytes"] as? FlutterStandardTypedData, let identifier = args?["identifier"] as? String {
                    self._printBluetooth(identifier: identifier, data: [UInt8](data.data), result: result)
                } else {
                    result(false)
                }
            default:
                result(FlutterMethodNotImplemented)
        }
    }
}
