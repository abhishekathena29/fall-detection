import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fall_detection/controller/local_notification.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
// import 'package:googleapis/fcm/v1.dart' as fcm;
// import 'package:googleapis/servicecontrol/v1.dart' as servicecontrol;
import 'package:googleapis_auth/auth_io.dart' as auth;

class FCMNotificationApi {
  final _firebaseMessaging = FirebaseMessaging.instance;
  Future<void> initNotification() async {
    await _firebaseMessaging.requestPermission();
    initialMessage();
    handleForegroundMessages();
    // handleBackgroundMessages();
  }

  Future<String?> getToken() async {
    try {
      final token =
          Platform.isAndroid
              ? await _firebaseMessaging.getToken()
              : await _firebaseMessaging.getAPNSToken();
      return token;
    } catch (e) {
      return "";
    }
  }

  Future<void> updateToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null && token.isNotEmpty) {
        var uid = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          "token": token,
        });
      }
    } catch (e) {
      log(e.toString());
    }
  }

  Future<void> initialMessage() async {
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();

    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  handleForegroundMessages() {
    FirebaseMessaging.onMessage.listen((message) async {
      if (message.notification != null) {
        log('Message also contained a notification: ${message.notification}');
      }
      await LocalNotification().showNotification(message);
    });
  }

  void _handleMessage(RemoteMessage message) {
    if (message.data['type'] == 'chat') {}
    log(message.data.toString());
  }

  Future<void> sendNotification(
    auth.AutoRefreshingAuthClient client,
    Map<String, dynamic> payload,
  ) async {
    try {
      var fcmUrl =
          "https://fcm.googleapis.com/v1/projects/fall-detection-b17ee/messages:send";

      final res = await client.post(
        Uri.parse(fcmUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200) {
        log('Notification sent successfully: ${res.body}');
      } else {
        log('Failed to send notification: ${res.statusCode}, ${res.body}');
      }
    } catch (e) {
      log("${e}fcm error");
    }
  }

  Future chatNotification(
    String msg,
    String token,
    String username, {
    String? profilePic,
  }) async {
    var client = await ServiceClient().getServiceClient();

    // if (LocalStore.getUserType() == "Student") {}
    var payload = {
      "message": {
        "token": token,
        "data": {"type": "chat"},
        "notification": {
          // if (profilePic != null) "image": profilePic,
          "title": username,
          "body": msg,
        },
      },
    };
    await sendNotification(client, payload);
  }
}

class ServiceClient with ChangeNotifier {
  auth.AutoRefreshingAuthClient? _client;
  auth.AutoRefreshingAuthClient? get client => _client;
  Future<auth.AutoRefreshingAuthClient> getServiceClient() async {
    try {
      final serviceAccountJson = {
        "type": "service_account",
        "project_id": "fall-detection-b17ee",
        "private_key_id": "d58730ab260f71a20337ab17cb10c2a3a98daf56",
        "private_key":
            "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDTP4WAf1tUelmB\nddlG5CzzdK+AjmliGZ6Vh1MgyofXjXqMXxa7m6W+UUd0C+1HjNNN4+Hjw9WR1bQd\ng7PX3Q4gXku38HmzzLPYgCUCffpyjj7klETPrYAWZVpKdwWFX0148RKrS5YXmWIu\nmi+xoxZLrZ5EawZ8W7IT399sRw0lhwgO1tXnqbgwmFpibWohcRAjyKwx5yVf57In\nEFk11cLBpx53Qhhzo9e16t7tthgXTYRnQV5OPqswjF3TV4xALmtw0D0EhIRJKxaQ\nDzPPNdWdFeQBgg7QQKVH6rtnM3lcSO0U1RZ09pnVk3S+i/aHOYfIwZMDr3rYXVTe\n6rZhCLVPAgMBAAECggEACfHw9F5f4QJBjyQKg+6KDzbBwb5H8nkHoOfWCgfUOARO\nbf1WsfkJ5y58ZqzeZtftEBBXuhlQx0+AQ0NysV7peKyic+5mTF3+uYU5jicle0R8\nbCvEHDgsJ4xt9m4pXGC4N6a3HPQEr5JmWjtNXizcsoNh8rv3JN5MQT3w5Bq+4Qf8\ne7QGIBCRC5BYVZ9vStbC84FOmVS1gq4omRPZSxORl/B4R4cB6J5VRUehh5tOWFPc\nBYrzOg76yyRzFlLBX5ZuaGADUQg3jvymNz6meBC77JdEz37ZHwZEWeIwz/nEfEb8\nzA1hJ3TaKhGdk5/YDslNQcSNc4ffkIekkxIe0n6bAQKBgQDorZkFcOHZ25GFoQ9j\nVLGgkZZtmoY4PoqhmTs2o/gAyQgDkrw7vVck28eilDYx0e2+RZt9qy4mRC4PlbgB\n+5gKhnPF6ITWMsfMioIp5olMamoMLRN1LJb8zFR51ZbGHvF2/r31VgHFczp8wgHn\nclx1gVIoQTX0XSLZyd58o77TfwKBgQDobAqNFRduQI4kIr3eHsazFtJDdiLZC9Fl\nzaEpvUXOSsJ9IhfGnfDULyNVov/1dTR8/6iwpmvwuRkykvzwE0MhEeB5PDsmhRy3\nqm4HzYZefr3eyp08ONgQdp5wvTU40qBjeCZoL/AMc/TEOA0u1emRsUT/4h2qg3sb\ntuYC7RLGMQKBgB9lRS+Jwr/Ns74PNG9XvzwGSQDzB8dREQ2rCmVeDJm2hoFM7F83\nNioACdjzHLjuNaEl7Uwwq+J38qshrZl+5E4PRFHhBQOOCI2d5uBWfhI0jaik8Gow\nIRNtUry5yEVlaXl/+AvBli2ZVbv9xZoAQV+NmpNZ8TjO1GQErCOvSJFrAoGBANju\nZpax1fG43TKLHq4gCZOEPHJs5C+zIRmk6MSdfXcDPi4vUQO3zN0utgsrHT4LzBbT\nRK7EVkETcppKqTymreRC3EIr3oWgfmJK93He+YhfQXadpE5ePAR5wn41i2Ri6wKM\nVUSvYZ0t6YnvSxao3911GJLAiLHrEE+Y0WxvvDMxAoGBAJyCWbbpxAzjObWCpHYr\nL3PX21iQKl55RblGELiG0o07hprlV72Wrcy4h93cd7opyDaHx5kKz+wQwcLnsKP4\nRrPIW7yKE5/wC9Rk7nuGHR1wlgqgNGXXoQTYDYA2difzN7OJBZF2V0ZyEonJJRz3\n6KZB3L9OYkPABwXCuFXnKrCj\n-----END PRIVATE KEY-----\n",
        "client_email":
            "firebase-adminsdk-fbsvc@fall-detection-b17ee.iam.gserviceaccount.com",
        "client_id": "109572935907263623761",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url":
            "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url":
            "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40fall-detection-b17ee.iam.gserviceaccount.com",
        "universe_domain": "googleapis.com",
      };

      const List<String> scopes = [
        'https://www.googleapis.com/auth/cloud-platform',
      ];
      final client = await auth.clientViaServiceAccount(
        auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
        scopes,
      );

      _client = client;
      notifyListeners();

      return client;
    } catch (e) {
      log(e.toString());
      rethrow;
    }
  }
}
