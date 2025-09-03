import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fall_detection/controller/fcm_notification.dart';
import 'package:fall_detection/controller/local_notification.dart';
import 'package:fall_detection/firebase_options.dart';
import 'package:fall_detection/pages/auth/login_page.dart';
import 'package:fall_detection/pages/auth/provider.dart';
import 'package:fall_detection/pages/auth/user_model.dart';
import 'package:fall_detection/pages/home/homepage.dart';
import 'package:fall_detection/pages/profile/provider/profile_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:background_task/background_task.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalNotification().intialize();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await BackgroundTask.instance.setBackgroundHandler(backgroundHandler);
  await FCMNotificationApi().initNotification();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthenProvider()),
        ChangeNotifierProvider(
          create: (_) => ProfileProvider()..getUserDetails(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await LocalNotification().showNotification(message);
}

@pragma('vm:entry-point')
void backgroundHandler(Location data) {
  debugPrint('backgroundHandler: ${DateTime.now()}, $data 12345325pi3430i09');
  Future(() async {
    debugPrint('in the background');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final auth = FirebaseAuth.instance.currentUser;

    final user =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(auth!.uid)
            .get();
    if (user.data()!['device'] != null) {
      final deviceId = user.data()!['device'];
      final res =
          await FirebaseFirestore.instance
              .collection('Devices')
              .doc(deviceId)
              .get();

      final userModel = UserModel.fromMap(user.data()!);

      Map<String, dynamic> deviceMap = res.data()!;

      final token = await FCMNotificationApi().getToken();
      List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(
        data.lat!.toDouble(),
        data.lng!.toDouble(),
      );

      String message = "";
      if (placemarks.isNotEmpty) {
        geo.Placemark place = placemarks[0];

        String address =
            "${place.street ?? ''}, "
            "${place.subLocality ?? ''}, "
            "${place.locality ?? ''}, "
            "${place.administrativeArea ?? ''} "
            "${place.postalCode ?? ''}, "
            "${place.country ?? ''}";

        // Trim any leading/trailing commas or spaces that might result from null values.
        message = address.replaceAll(RegExp(r', $'), '').trim();
      }

      if (deviceMap['alert'] == 1) {
        for (var uid in userModel.related) {
          final related =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .get();
          final relatedToken = related.data()!['token'];
          await FCMNotificationApi().chatNotification(
            message,
            relatedToken,
            userModel.name,
          );
        }

        await FirebaseFirestore.instance
            .collection('Devices')
            .doc(deviceId)
            .update({'alert': 0});
      }
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fall Detection',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Consumer<AuthenProvider>(
        builder: (context, provider, _) {
          if (provider.isAuthenticated) {
            return HomePage();
          } else {
            return AuthScreen();
          }
        },
      ),
    );
  }
}
