import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String? uid;
  final String name;
  final String email;
  final String token;
  final String? device;
  final List<String> related;
  final Timestamp createdAt;
  UserModel({
    this.uid,
    required this.name,
    required this.email,
    this.device,
    required this.token,
    required this.related,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'token': token,
      'related': related,
      'createdAt': createdAt,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      device: map['device'],
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      token: map['token'] ?? '',
      related: List<String>.from(map['related']),
      createdAt: map['createdAt'],
    );
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source));
}

class Connection {
  final String uid;
  final String token;
  Connection({required this.uid, required this.token});

  Map<String, dynamic> toMap() {
    return {'uid': uid, 'token': token};
  }

  factory Connection.fromMap(Map<String, dynamic> map) {
    return Connection(uid: map['uid'] ?? '', token: map['token'] ?? '');
  }
}
