import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';

/// Handles dummy authentication for MVP demo.
/// In production, replace with Firebase Auth (Google Sign-In, phone OTP, etc.)
class AuthService extends ChangeNotifier {
  String? _userId;
  String? _userName;
  String _city = 'Nashik';
  bool _isLoading = false;

  String get userId => _userId ?? AppConstants.dummyUserId;
  String get userName => _userName ?? AppConstants.dummyUserName;
  String get city => _city;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _userId != null;

  AuthService() {
    _initDummyUser();
  }

  /// Create or restore a dummy user session using SharedPreferences.
  /// This simulates authentication without requiring Firebase Auth setup.
  Future<void> _initDummyUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id');
      _userName = prefs.getString('user_name');
      _city = prefs.getString('user_city') ?? 'Nashik';

      // First time: generate a unique ID
      if (_userId == null) {
        _userId = const Uuid().v4();
        _userName = 'Citizen_${_userId!.substring(0, 6)}';
        await prefs.setString('user_id', _userId!);
        await prefs.setString('user_name', _userName!);
        await prefs.setString('user_city', _city);
      }
    } catch (e) {
      debugPrint('Auth init error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Update user's city
  Future<void> setCity(String city) async {
    _city = city;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_city', city);
    notifyListeners();
  }

  /// Update display name
  Future<void> setUserName(String name) async {
    _userName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    notifyListeners();
  }
}
