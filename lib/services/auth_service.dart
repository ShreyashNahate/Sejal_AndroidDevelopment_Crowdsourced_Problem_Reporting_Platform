import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Handles user session for MVP.
/// Uses SharedPreferences to persist userId, name, city across app launches.
/// All Firestore data is linked to userId (UUID generated once on first launch).
class AuthService extends ChangeNotifier {
  String? _userId;
  String? _userName;
  String _city = '';
  bool _isLoading = true;
  bool _isNewUser = false; // true = show onboarding

  String get userId => _userId ?? '';
  String get userName => _userName ?? 'Citizen';
  String get city => _city;
  bool get isLoading => _isLoading;
  bool get isNewUser => _isNewUser;
  bool get isLoggedIn =>
      _userId != null && _userName != null && _city.isNotEmpty;

  AuthService() {
    _init();
  }

  /// On first launch: generate UUID, set _isNewUser = true → show onboarding.
  /// On subsequent launches: restore saved session → go directly to home.
  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id');
      _userName = prefs.getString('user_name');
      _city = prefs.getString('user_city') ?? '';

      if (_userId == null) {
        // First launch — generate persistent UUID
        _userId = const Uuid().v4();
        await prefs.setString('user_id', _userId!);
        _isNewUser = true; // trigger onboarding screen
      } else if (_userName == null || _city.isEmpty) {
        // Has ID but didn't finish onboarding
        _isNewUser = true;
      }
    } catch (e) {
      debugPrint('Auth init error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Called from onboarding screen when user submits name + city.
  /// Saves to SharedPreferences and also creates user doc in Firestore.
  Future<void> completeOnboarding({
    required String name,
    required String city,
  }) async {
    _userName = name.trim();
    _city = city.trim();
    _isNewUser = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _userName!);
    await prefs.setString('user_city', _city);

    notifyListeners();
  }

  /// Update name from profile screen
  Future<void> setUserName(String name) async {
    _userName = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _userName!);
    notifyListeners();
  }

  /// Update city from profile screen
  Future<void> setCity(String city) async {
    _city = city.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_city', _city);
    notifyListeners();
  }

  /// Clear session (logout/reset for testing)
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _userId = null;
    _userName = null;
    _city = '';
    _isNewUser = true;
    notifyListeners();
  }
}
