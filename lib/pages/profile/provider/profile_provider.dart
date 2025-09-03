import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fall_detection/pages/auth/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  UserModel? _user;
  UserModel? get user => _user;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  getUserDetails() async {
    _loading = true;
    notifyListeners();
    try {
      final res =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .get();

      final map = res.data()!;
      map['uid'] = res.id;
      _user = UserModel.fromMap(map);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
