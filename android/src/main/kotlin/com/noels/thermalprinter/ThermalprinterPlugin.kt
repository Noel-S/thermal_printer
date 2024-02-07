package com.noels.thermalprinter

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.bluetooth.le.ScanSettings
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.os.CountDownTimer
import android.util.Log

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.StreamHandler
import java.util.UUID

/** ThermalprinterPlugin */
class ThermalprinterPlugin: FlutterPlugin, MethodCallHandler, StreamHandler {
  private val serialUUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805f9b34fb")

  private lateinit var channel : MethodChannel
  private lateinit var eventChannel: EventChannel
  private lateinit var bluetoothManager: BluetoothManager

  var bluetoothScanSink: EventChannel.EventSink? = null
//  var usbScanSink: EventChannel.EventSink? = null


  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    bluetoothManager = flutterPluginBinding.applicationContext.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "thermalprinter_channel")
    channel.setMethodCallHandler(this)
    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "thermalprinter")
    eventChannel.setStreamHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
        "status" -> isEnabled(result)
        "printBluetooth" -> call.argument<String>("identifier")?.let {
            Log.d("ENTER", "onMethodCall: SIU")
            call.argument<ByteArray>("bytes")?.let { bytes ->
              printBluetooth(it, bytes, result)
            }
        }
        "connectBluetooth" -> call.argument<String>("identifier")?.let {
            connectBluetooth(it, result)
        }
        else -> {
            result.notImplemented()
        }
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
      channel.setMethodCallHandler(null)
      eventChannel.setStreamHandler(null)
  }

  private fun isEnabled(result: Result) {
    if (bluetoothManager.adapter == null) {
            result.error(
                "BLUETOOTH_NOT_SUPPORTED",
                "The current device doesn't support bluetooth connectivity.",
                "Tried to get adapter from bluetooth manager."
            )
            return
        }
        result.success(bluetoothManager.adapter?.isEnabled)
  }

  private fun printBluetooth(address: String, data: ByteArray, result: Result) {
//    Log.d("METHOD_CHANNEL", "_print: ${data.size}")
    if (bluetoothManager.adapter == null) {
        Log.e("BLUETOOTH", "The current device doesn't support bluetooth connectivity.")
        result.success(false)
        return
    }
    val device: BluetoothDevice = bluetoothManager.adapter.getRemoteDevice(address)
    val socket: BluetoothSocket = device.createRfcommSocketToServiceRecord(serialUUID)

    Thread {
        try {
            closeSocketConnection(socket)
            socket.connect()
            socket.outputStream.write(data, 0, data.size)
            result.success(true)
        } catch (e: Exception) {
            closeSocketConnection(socket)
//                result.success(false)
            result.error("EXCEPTION", e.message, e.localizedMessage)
        } finally {
            Thread.sleep(1500)
            closeSocketConnection(socket)
        }
    }.start()
  }

    private fun connectBluetooth(address: String, result: Result) {
//    Log.d("METHOD_CHANNEL", "_print: ${data.size}")
        if (bluetoothManager.adapter == null) {
            Log.e("BLUETOOTH", "The current device doesn't support bluetooth connectivity.")
            result.success(false)
            return
        }
        val device: BluetoothDevice = bluetoothManager.adapter.getRemoteDevice(address)
        val socket: BluetoothSocket = device.createRfcommSocketToServiceRecord(serialUUID)

        Thread {
            try {
                closeSocketConnection(socket)
                socket.connect()
                result.success(true)
            } catch (e: Exception) {
                closeSocketConnection(socket)
                result.error("EXCEPTION", e.message, e.localizedMessage)
            } finally {
                Thread.sleep(700)
                closeSocketConnection(socket)
            }
        }.start()
    }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        val args: Map<*, *> = arguments as Map<*, *> // {'method': 'scan', 'timeout': timeout, 'type': type.name}
//        print(arguments)
//        events?.success(arguments)
        val timeout: Long = (args["timeout"] as Number).toLong()
        if (args["method"] == "scan") {
            bluetoothScanSink?.endOfStream()
            bluetoothScanSink = events
            scanBluetooth(timeout)
        }
    }

  override fun onCancel(arguments: Any?) {
      bluetoothScanSink?.success(arguments)
      bluetoothScanSink?.endOfStream()
      print(arguments)
  }

    private fun closeSocketConnection(socket: BluetoothSocket) {
        if (socket.isConnected) {
            socket.outputStream.flush()
            socket.outputStream.close()
            socket.close()
        }
    }

    private val scanCallback: ScanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            if (result.device.name != null) {
                val device: MutableMap<String, Any> = HashMap()
                device["identifier"] = result.device.address
                device["name"] = result.device.name
                device["type"] = result.device.type
                bluetoothScanSink?.success(device)
            }
        }
    }

  private fun scanBluetooth(time: Long) {
        // 0:lowPower 1:balanced 2:lowLatency -1:opportunistic
        val settings: ScanSettings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build()
        bluetoothManager.adapter.bluetoothLeScanner.startScan(null, settings, scanCallback)
        val timer = object: CountDownTimer(time, 1000) {
            override fun onTick(millisUntilFinished: Long) {}

            override fun onFinish() {
                bluetoothManager.adapter.bluetoothLeScanner.stopScan(scanCallback)
                bluetoothScanSink?.endOfStream()
            }
        }
        timer.start()
    }
}
