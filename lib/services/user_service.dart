import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../constants/app_constants.dart';

/// Manages user profiles and trust scores in Firestore
class UserService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  /// Load or create user profile from Firestore
  Future<void> loadUser(String userId, String name, String city) async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await _db.collection('users').doc(userId).get();

      if (doc.exists) {
        _currentUser = UserModel.fromMap(doc.data()!, userId);
      } else {
        // Create new user with default trust score
        final newUser = UserModel(
          id: userId,
          name: name,
          trustScore: AppConstants.defaultTrustScore,
          issuesReported: 0,
          votescast: 0,
          city: city,
          createdAt: DateTime.now(),
        );
        await _db.collection('users').doc(userId).set(newUser.toMap());
        _currentUser = newUser;
      }
    } catch (e) {
      debugPrint('Load user error: $e');
      // Fallback to default user
      _currentUser = UserModel(
        id: userId,
        name: name,
        trustScore: AppConstants.defaultTrustScore,
        issuesReported: 0,
        votescast: 0,
        city: city,
        createdAt: DateTime.now(),
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Get trust score for the current user
  double get trustScore =>
      _currentUser?.trustScore ?? AppConstants.defaultTrustScore;

  /// Reload user from Firestore
  Future<void> refresh(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        _currentUser = UserModel.fromMap(doc.data()!, userId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Refresh user error: $e');
    }
  }
}
