import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final _db = FirebaseFirestore.instance;

  /// Register a new user in Firestore
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String role,
    required String contact,
  }) async {
    try {
      // check if user already exists
      final existing = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (existing.docs.isNotEmpty) {
        return 'User already exists';
      }

      // save user data to Firestore
      await _db.collection('users').add({
        'name': name,
        'email': email,
        'password': password, // plain text (for demo only)
        'role': role,
        'contact': contact,
        'createdAt': DateTime.now(),
      });

      return null; // success
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  /// Login user by checking Firestore data
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final snapshot = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .where('password', isEqualTo: password)
          .get();

      if (snapshot.docs.isEmpty) {
        return 'Invalid email or password';
      }

      return null; // success
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  /// Get user role (for navigation)
  Future<String?> getUserRole(String email) async {
    try {
      final snapshot = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.data()['role'] as String?;
    } catch (e) {
      return null;
    }
  }
}
