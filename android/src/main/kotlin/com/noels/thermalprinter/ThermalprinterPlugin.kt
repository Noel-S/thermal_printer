package com.noels.thermalprinter

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.CountDownTimer
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.InputStream
import java.util.UUID
import kotlin.coroutines.CoroutineContext

/** ThermalprinterPlugin */
class ThermalprinterPlugin: FlutterPlugin, MethodCallHandler, StreamHandler, CoroutineScope {
    private lateinit var job: Job
  private val serialUUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805f9b34fb")

  private lateinit var channel : MethodChannel
  private lateinit var eventChannel: EventChannel
  private lateinit var bluetoothManager: BluetoothManager

  var bluetoothScanSink: EventChannel.EventSink? = null
//  var usbScanSink: EventChannel.EventSink? = null
  private var bluetoothDevicesHash : HashMap<String, BluetoothSocket> = HashMap()

  override val coroutineContext: CoroutineContext
    get() = Dispatchers.Main + job


  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
      job = Job()
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
        "disconnectBluetooth" -> call.argument<String>("identifier")?.let {
            disconnectBluetooth(it, result)
        }
        else -> {
            result.notImplemented()
        }
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
      job.cancel()
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

  private fun printBluetooth(address: String, data: ByteArray, result: Result) = launch(Dispatchers.IO) {
//    Log.d("METHOD_CHANNEL", "_print: ${data.size}")
    if (bluetoothManager.adapter == null) {
        Log.e("BLUETOOTH", "The current device doesn't support bluetooth connectivity.")
        result.success(false)
        throw Exception("The current device doesn't support bluetooth connectivity.")
    }
      var socket: BluetoothSocket? = bluetoothDevicesHash[address]
      if (socket == null) {
        val device: BluetoothDevice = bluetoothManager.adapter.getRemoteDevice(address)
        socket = device.createRfcommSocketToServiceRecord(serialUUID)
        bluetoothDevicesHash[address] = socket
      }

        try {
            //closeSocketConnection(socket!)
            socket!!.connect()
            val byteArray = byteArrayOf(0x1B, 0x40)
            socket.outputStream.write(byteArray, 0, byteArray.size)
            // Now, instead of sleeping, listen for acknowledgment
//            val acknowledgment = readAcknowledgment(socket.inputStream)
//            if (!acknowledgment) {
//                throw Exception("No acknowledgment received")
//            }
            socket.outputStream.write(data, 0, data.size)
            socket.outputStream.flush()
            val printAcknowledgment = readAcknowledgment(socket.inputStream)
            if (!printAcknowledgment) {
                throw Exception("Print job not acknowledged")
            }

            //Thread.sleep(1500)
            delay(2000)
//            result.success(true)
//            bluetoothDevicesHash.remove(address)
            withContext(Dispatchers.Main) {
                result.success(true)
            }
        } catch (e: Exception) {
            withContext(Dispatchers.Main) {
                result.success(false)
            }
//            result.error("EXCEPTION", e.message, e.localizedMessage)
        }
  }



    private suspend fun readAcknowledgment(inputStream: InputStream):Boolean {
        val buffer = ByteArray(1024) // Buffer for storing incoming bytes
        var attempts = 0
        val maxAttempts = 10 // For example, wait for up to 10 iterations

        var done = false
        while (!done && attempts < maxAttempts) {
            if (withContext(Dispatchers.IO) {
                    inputStream.available()
                } > 0) {
                val numBytes = withContext(Dispatchers.IO) {
                    inputStream.read(buffer)
                }
                val readMessage = String(buffer, 0, numBytes)
                // Log or process the readMessage here. For now, just log it.
                withContext(Dispatchers.Main) {
                    Log.d("BLUETOOTH_PRINTER", "Received: $readMessage")
                }
                done = true // Adjust this based on your criteria
            } else {
                delay(500)
                attempts++
            }
        }

        if (attempts >= maxAttempts) {
            withContext(Dispatchers.Main) {
                Log.e("BLUETOOTH_PRINTER", "No response received within the expected timeframe.")
            }
            return false // Placeholder
        }
        return true // Placeholder
    }

    private fun connectBluetooth(address: String, result: Result) {
        try {
            if (bluetoothManager.adapter == null) {
                Log.e("BLUETOOTH", "The current device doesn't support bluetooth connectivity.")
                result.success(false)
                throw Exception("The current device doesn't support bluetooth connectivity.")
            }
            var socket: BluetoothSocket? = bluetoothDevicesHash[address]
            if (socket == null) {
                val device: BluetoothDevice = bluetoothManager.adapter.getRemoteDevice(address)
                socket = device.createRfcommSocketToServiceRecord(serialUUID)
                bluetoothDevicesHash[address] = socket
            }
            if (!socket!!.isConnected) {
                socket.connect()
            }
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
//            result.error("EXCEPTION", e.message, e.localizedMessage)
        }
//        if (bluetoothManager.adapter == null) {
//            Log.e("BLUETOOTH", "The current device doesn't support bluetooth connectivity.")
//            result.success(false)
//            return
//        }
//        val device: BluetoothDevice = bluetoothManager.adapter.getRemoteDevice(address)
//        val socket: BluetoothSocket = device.createRfcommSocketToServiceRecord(serialUUID)
//
//        Thread {
//            try {
//                closeSocketConnection(socket)
//                socket.connect()
//                result.success(true)
//            } catch (e: Exception) {
//                closeSocketConnection(socket)
//                result.error("EXCEPTION", e.message, e.localizedMessage)
//            } finally {
//                Thread.sleep(700)
//                closeSocketConnection(socket)
//            }
//        }.start()
    }

    private fun disconnectBluetooth(address: String, result: Result) {
        try {
            if (bluetoothManager.adapter == null) {
                Log.e("BLUETOOTH", "The current device doesn't support bluetooth connectivity.")
                result.success(false)
                throw Exception("The current device doesn't support bluetooth connectivity.")
            }
            val socket: BluetoothSocket? = bluetoothDevicesHash[address]
            if (socket == null) {
                result.success(true)
                return
            }
            if (!socket.isConnected) {
                result.success(true)
                return
            }
            socket.outputStream.flush()
            socket.outputStream.close()
            socket.close()

            bluetoothDevicesHash.remove(address)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
//            result.error("EXCEPTION", e.message, e.localizedMessage)
        }
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
        try {
            if (socket.isConnected) {
                socket.outputStream.flush()
                socket.outputStream.close()
                socket.close()
            }
        } catch (_: Exception) {}
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
