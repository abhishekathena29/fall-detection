import 'dart:io';

import 'package:background_task/background_task.dart';
import 'package:fall_detection/controller/fcm_notification.dart';
import 'package:fall_detection/pages/profile/profile.dart';
import 'package:fall_detection/pages/profile/provider/profile_provider.dart';
import 'package:fall_detection/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isStarted = false;
  String _bgText = 'no start';
  String _statusText = 'status';
  bool _isEnabledEvenIfKilled = true;

  late final StreamSubscription<Location> _bgDisposer;
  late final StreamSubscription<StatusEvent> _statusDisposer;

  @override
  void initState() {
    _bgDisposer = BackgroundTask.instance.stream.listen((event) {
      final message =
          'BG Disposer ${DateTime.now()}: ${event.lat}, ${event.lng}';
      debugPrint(message);
      setState(() {
        _bgText = message;
      });
    });

    //update the token
    Future.microtask(() async {
      await FCMNotificationApi().updateToken();
    });

    Future(() async {
      await _determinePosition();
      final result = await Permission.notification.request();
      debugPrint('notification: $result');
      if (Platform.isAndroid) {
        if (result.isGranted) {
          await BackgroundTask.instance.setAndroidNotification(
            title: 'Location',
            message: _bgText,
          );
        }
      }
    });

    _statusDisposer = BackgroundTask.instance.status.listen((event) {
      final message =
          'status: ${event.status.value}, message: ${event.message}';
      setState(() {
        _statusText = message;
      });
    });

    super.initState();
  }

  _startBackgroundTask() async {
    setState(() {
      _isStarted = true;
    });

    final status = await Permission.location.request();
    final statusAlways = await Permission.locationAlways.request();

    if (status.isGranted && statusAlways.isGranted) {
      await BackgroundTask.instance.start(
        isEnabledEvenIfKilled: _isEnabledEvenIfKilled,
      );
      setState(() {
        _bgText = 'start';
      });
    } else {
      setState(() {
        _bgText =
            'Permission is not isGranted.\n'
            'location: $status\n'
            'locationAlways: $status';
      });
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.requestPermission();
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
    }

    await Geolocator.getCurrentPosition();
  }

  @override
  void dispose() {
    _bgDisposer.cancel();
    _statusDisposer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Sensor Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              moveTo(context, ProfilePage());
            },
            icon: const Icon(
              Icons.account_circle,
              color: Colors.white,
              size: 28,
            ),
            tooltip: 'Profile',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Start/Stop Button
            Container(
              height: 80,
              margin: const EdgeInsets.only(bottom: 30),
              child: ElevatedButton(
                onPressed: () {
                  _startBackgroundTask();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isStarted ? Colors.red[600] : Colors.green[600],
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isStarted ? Icons.stop : Icons.play_arrow, size: 32),
                    const SizedBox(width: 10),
                    Text(
                      _isStarted ? 'STOP' : 'START',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sensor Value Display
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Sensor Reading',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    Consumer<ProfileProvider>(
                      builder: (context, provider, _) {
                        if (provider.user != null &&
                            provider.user!.device != null) {
                          return Text(provider.user!.device.toString());
                        }
                        return SizedBox();
                      },
                    ),
                    const SizedBox(height: 20),
                    // Text(
                    //   _sensorValue.toStringAsFixed(2),
                    //   style: TextStyle(
                    //     fontSize: 72,
                    //     fontWeight: FontWeight.bold,
                    //     color: _isStarted ? Colors.blue[700] : Colors.grey[400],
                    //   ),
                    // ),
                    const SizedBox(height: 10),
                    Text(
                      'Units',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 30),

                    // Status Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _isStarted ? Colors.green[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _isStarted ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isStarted ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color:
                                  _isStarted
                                      ? Colors.green[800]
                                      : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Info Section
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Press START to begin sensor monitoring. Tap the profile icon to view settings.',
                      style: TextStyle(color: Colors.blue[800], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Make Sure to Grant the Location Permission',
                      style: TextStyle(color: Colors.blue[800], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
