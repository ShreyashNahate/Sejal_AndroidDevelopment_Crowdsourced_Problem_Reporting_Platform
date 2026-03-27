import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/issue_model.dart';
import '../models/vote_model.dart';
import '../constants/app_constants.dart';
// Add this import at the top of issue_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for all issue-related Firebase operations.
/// Handles: create, read, vote, priority calculation, duplicate detection.
class IssueService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<IssueModel> _issues = [];
  List<IssueModel> _emergencyIssues = [];
  bool _isLoading = false;
  String? _error;

  List<IssueModel> get issues => _issues;
  List<IssueModel> get emergencyIssues => _emergencyIssues;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch all issues from Firestore, ordered by priority
  Future<void> fetchIssues() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _db
          .collection('issues')
          .orderBy('priority_score', descending: true)
          .limit(100)
          .get();

      _issues = snapshot.docs
          .map((doc) => IssueModel.fromMap(doc.data(), doc.id))
          .toList();

      // Separate emergency issues
      _emergencyIssues = _issues.where((i) => i.isEmergency).toList();
    } catch (e) {
      _error = 'Failed to load issues: $e';
      debugPrint(_error);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Stream issues in real-time from Firestore
  Stream<List<IssueModel>> streamIssues() {
    return _db
        .collection('issues')
        .orderBy('priority_score', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => IssueModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Upload image to Cloudinary (free tier) and return the secure URL.
  /// Cloudinary free tier: 25GB storage + 25GB bandwidth/month.
  /// Setup: cloudinary.com → Settings → Upload Presets → create unsigned preset
  Future<String?> uploadImage(File imageFile) async {
    try {
      // 🔧 REPLACE these two values with yours from Cloudinary dashboard
      const cloudName = 'dqbsprma5'; // e.g. 'dxyz123abc'
      const uploadPreset = 'SmartCity'; // e.g. 'smartcity_unsigned'

      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      // Multipart POST request — no API key needed for unsigned preset
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'smartcity_issues' // organizes uploads in a folder
        ..files.add(
          await http.MultipartFile.fromPath('file', imageFile.path),
        );

      final response = await request.send();

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final json = jsonDecode(body) as Map<String, dynamic>;
        // Returns HTTPS URL — store this in Firestore
        return json['secure_url'] as String?;
      } else {
        debugPrint('Cloudinary upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Image upload error: $e');
      return null;
    }
  }

  /// Check for duplicate: same location (within ~100m) + same category within 24h
  Future<bool> isDuplicate({
    required double latitude,
    required double longitude,
    required String category,
  }) async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));

      final snapshot = await _db
          .collection('issues')
          .where('category', isEqualTo: category)
          .where('created_at', isGreaterThan: yesterday.millisecondsSinceEpoch)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lat = (data['latitude'] as num).toDouble();
        final lng = (data['longitude'] as num).toDouble();

        // Rough distance check (~111m per 0.001 degree)
        final latDiff = (lat - latitude).abs();
        final lngDiff = (lng - longitude).abs();
        if (latDiff < 0.001 && lngDiff < 0.001) {
          return true; // Duplicate found
        }
      }
    } catch (e) {
      debugPrint('Duplicate check error: $e');
    }
    return false;
  }

  /// Check how many issues user submitted in last hour (spam prevention)
  Future<int> getUserSubmissionsLastHour(String userId) async {
    try {
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      final snapshot = await _db
          .collection('issues')
          .where('user_id', isEqualTo: userId)
          .where('created_at', isGreaterThan: oneHourAgo.millisecondsSinceEpoch)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Submit a new issue to Firestore
  Future<String?> submitIssue({
    required File? imageFile,
    required double latitude,
    required double longitude,
    required String category,
    required String description,
    required bool isEmergency,
    required bool isAnonymous,
    required String userId,
    required String userName,
    required String city,
  }) async {
    try {
      // Image is mandatory for real complaints
      if (imageFile == null) {
        return 'Please attach an image of the issue.';
      }

      // Spam check: max 5 submissions per hour
      if (!isAnonymous) {
        final count = await getUserSubmissionsLastHour(userId);
        if (count >= 5) {
          return 'You have submitted too many reports in the last hour. Please wait.';
        }
      }

      // Duplicate check
      final isDup = await isDuplicate(
        latitude: latitude,
        longitude: longitude,
        category: category,
      );
      if (isDup) {
        return 'A similar issue has already been reported at this location recently.';
      }

      // Upload image
      final imageUrl = await uploadImage(imageFile);
      if (imageUrl == null) {
        return 'Failed to upload image. Check internet connection.';
      }

      // Calculate initial priority score
      // Base = 1.0, Emergency adds 50 bonus points
      final priorityScore = isEmergency ? AppConstants.emergencyBoost : 1.0;

      // Create the issue document
      final issueRef = _db.collection('issues').doc();
      final issue = IssueModel(
        id: issueRef.id,
        imageUrl: imageUrl,
        latitude: latitude,
        longitude: longitude,
        category: category,
        description: description,
        status: AppConstants.statusPending,
        isEmergency: isEmergency,
        isAnonymous: isAnonymous,
        userId: isAnonymous ? null : userId,
        userName: isAnonymous ? null : userName,
        priorityScore: priorityScore,
        voteCount: 0,
        createdAt: DateTime.now(),
        city: city,
      );

      await issueRef.set(issue.toMap());

      // Update user's issue count (skip for anonymous)
      if (!isAnonymous) {
        await _db.collection('users').doc(userId).set(
          {'issues_reported': FieldValue.increment(1)},
          SetOptions(merge: true),
        );
      }

      // Update city stats
      await _db.collection('city_stats').doc(city).set(
        {'issue_count': FieldValue.increment(1), 'city': city},
        SetOptions(merge: true),
      );

      return null; // null = success
    } catch (e) {
      debugPrint('Submit issue error: $e');
      return 'An error occurred. Please try again.';
    }
  }

  /// Cast a vote on an issue (weighted by user trust score)
  Future<bool> voteOnIssue({
    required String issueId,
    required String userId,
    required double trustScore,
  }) async {
    try {
      // Check if user already voted on this issue
      final existingVote = await _db
          .collection('votes')
          .where('issue_id', isEqualTo: issueId)
          .where('user_id', isEqualTo: userId)
          .get();

      if (existingVote.docs.isNotEmpty) {
        return false; // Already voted
      }

      // Calculate vote weight from trust score
      final weight = trustScore.clamp(0.5, 3.0);

      // Add vote record
      await _db.collection('votes').add({
        'issue_id': issueId,
        'user_id': userId,
        'weight': weight,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      // Update issue priority score and vote count
      // Priority = sum of all vote weights + emergency boost
      final issueRef = _db.collection('issues').doc(issueId);
      await issueRef.update({
        'priority_score': FieldValue.increment(weight),
        'vote_count': FieldValue.increment(1),
      });

      // Increase voter's trust score slightly (reward participation)
      await _db.collection('users').doc(userId).set(
        {
          'trust_score': FieldValue.increment(0.01),
          'votes_cast': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );

      return true;
    } catch (e) {
      debugPrint('Vote error: $e');
      return false;
    }
  }

  /// Update issue status (admin function)
  Future<void> updateStatus(String issueId, String status) async {
    await _db.collection('issues').doc(issueId).update({'status': status});
    await fetchIssues();
  }

  /// Get city-wise issue statistics for leaderboard
  Future<List<Map<String, dynamic>>> getCityStats() async {
    try {
      final snapshot = await _db
          .collection('city_stats')
          .orderBy('issue_count', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('City stats error: $e');
      return [];
    }
  }
}
