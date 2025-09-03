import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fall_detection/controller/fcm_notification.dart';
import 'package:fall_detection/pages/auth/user_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthenProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  AuthenProvider() {
    _user = _auth.currentUser;
    _auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isAuthenticated => _user != null;

  bool _loading = false;
  bool get loading => _loading;

  /// Login with Email & Password
  Future<bool> login(String email, String password) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return res.user != null;
    } on FirebaseAuthException catch (e) {
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Sign Up with Email & Password
  Future<bool> signUp(String email, String password, String name) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final token = await FCMNotificationApi().getToken();
      if (res.user != null) {
        final user = UserModel(
          name: name,
          email: email,
          related: [],
          token: token ?? "",
          createdAt: Timestamp.now(),
        );
        await FirebaseFirestore.instance
            .collection('users')
            .doc(res.user!.uid)
            .set(user.toMap());
        await res.user!.updateDisplayName(name);
      }
      return res.user != null;
    } on FirebaseAuthException catch (e) {
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Logout
  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }
}
