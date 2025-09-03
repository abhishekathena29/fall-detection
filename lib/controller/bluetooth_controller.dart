import 'dart:developer';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BlueToothRepository {
  static final BlueToothRepository instance = BlueToothRepository._internal();
  factory BlueToothRepository() => instance;
  BlueToothRepository._internal();

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? characteristic;
  Future<void> initialize() async {
    log('Bluetooth starting');
    await _setupBluetooth();
    // _startScanning();
    // await startForegroundService();
  }

  Future<void> _setupBluetooth() async {
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        _startScanning();
      }
    });

    // if (await FlutterBluePlus.adapterState.) {
    //   _startScanning();
    // }
  }

  void _startScanning() {
    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        log(r.advertisementData.advName);
        if (r.device.advName == "ESP32_WIFI_SETUP") {
          discoverServices(r.device);
          break;
        }
      }
    });
    FlutterBluePlus.startScan(
      timeout: Duration(seconds: 4),
      androidUsesFineLocation: true,
    );
  }

  String _imuData = "No Data";
  String get imuData => _imuData;

  void discoverServices(BluetoothDevice device) async {
    connectedDevice = device;
    await device.connect();
    var services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
        for (var char in service.characteristics) {
          if (char.uuid.toString() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
            characteristic = char;
            char.setNotifyValue(true);
            char.lastValueStream.listen((value) {
              _processValue(value);
            });
            char.value.listen((value) {
              _imuData = String.fromCharCodes(value);
              log(_imuData);
              // notifyListeners();
            });
            // var l =  char.lastValueStream.listen(onData);
          } else if (char.uuid.toString() ==
              "d61b2e19-2346-4a9e-9fb4-d87432c2d89b") {
            // setState(() {
            //   commandCharacteristic = char;
            // });
          }
        }
      }
    }
  }

  _processValue(List<int> value) {}

  void sendCommand(String cmd) async {
    await characteristic!.write(cmd.codeUnits);
  }
}
