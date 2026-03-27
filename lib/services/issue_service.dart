import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/issue_model.dart';
import '../models/vote_model.dart';
import '../constants/app_constants.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for all issue-related Firebase operations.
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

  /// Upload image to Cloudinary
  Future<String?> uploadImage(File imageFile) async {
    try {
      const cloudName = 'dqbsprma5';
      const uploadPreset = 'SmartCity';

      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'smartcity_issues'
        ..files.add(
          await http.MultipartFile.fromPath('file', imageFile.path),
        );

      final response = await request.send();

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final json = jsonDecode(body) as Map<String, dynamic>;
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

  /// All spam/fraud/duplicate checks in one place.
  /// Fetches user's issues ONCE and does all checks in Dart — no compound queries.
  /// Returns error string if blocked, null if clean.
  Future<String?> _runAllChecks({
    required String userId,
    required String description,
    required double latitude,
    required double longitude,
    required String category,
  }) async {
    // ── 1. Client-side description checks (no Firestore needed) ──
    final desc = description.trim();

    if (desc.length < 10) {
      return 'Description too short. Please describe the issue properly.';
    }

    final allSameChar = desc.split('').every((c) => c == desc[0]);
    if (allSameChar) {
      return 'Please enter a valid description.';
    }

    // ── 2. Fetch ALL issues by this user (single query, no index needed) ──
    List<Map<String, dynamic>> userIssues = [];
    try {
      final snap = await _db
          .collection('issues')
          .where('user_id', isEqualTo: userId)
          .get();
      userIssues = snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint('User issues fetch error: $e');
    }

    final now = DateTime.now();
    final twoMinsAgo = now.subtract(const Duration(minutes: 2));
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    final oneDayAgo = now.subtract(const Duration(hours: 24));

    // ── 3. Cooldown: no submission in last 2 minutes ──
    final onCooldown = userIssues.any((d) {
      final ts = d['created_at'] as int?;
      if (ts == null) return false;
      return DateTime.fromMillisecondsSinceEpoch(ts).isAfter(twoMinsAgo);
    });
    if (onCooldown) {
      return 'Please wait 2 minutes before submitting another report.';
    }

    // ── 4. Hourly limit: max 5 per hour ──
    final hourlyCount = userIssues.where((d) {
      final ts = d['created_at'] as int?;
      if (ts == null) return false;
      return DateTime.fromMillisecondsSinceEpoch(ts).isAfter(oneHourAgo);
    }).length;
    if (hourlyCount >= 5) {
      return 'You have submitted too many reports in the last hour. Please wait.';
    }

    // ── 5. Daily limit: max 10 per day ──
    final dailyCount = userIssues.where((d) {
      final ts = d['created_at'] as int?;
      if (ts == null) return false;
      return DateTime.fromMillisecondsSinceEpoch(ts).isAfter(oneDayAgo);
    }).length;
    if (dailyCount >= 10) {
      return 'You have exceeded your daily report limit (10 per day).';
    }

    // ── 6. Same user, same category within 500m in last 24h ──
    final sameUserDup = userIssues.any((d) {
      final ts = d['created_at'] as int?;
      if (ts == null) return false;
      if (!DateTime.fromMillisecondsSinceEpoch(ts).isAfter(oneDayAgo)) {
        return false;
      }
      if (d['category'] != category) return false;
      final lat = (d['latitude'] as num?)?.toDouble();
      final lng = (d['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return false;
      return (lat - latitude).abs() < 0.005 && (lng - longitude).abs() < 0.005;
    });
    if (sameUserDup) {
      return 'You already reported a $category issue near this location recently.';
    }

    // ── 7. Duplicate description check (anyone, last 24h) ──
    try {
      final descSnap = await _db
          .collection('issues')
          .where('description', isEqualTo: desc)
          .get();

      final descDup = descSnap.docs.any((doc) {
        final ts = doc.data()['created_at'] as int?;
        if (ts == null) return false;
        return DateTime.fromMillisecondsSinceEpoch(ts).isAfter(oneDayAgo);
      });

      if (descDup) {
        return 'This exact issue description was already submitted recently.';
      }
    } catch (e) {
      debugPrint('Desc dup check error: $e');
    }

    // ── 8. Location duplicate: same category, same spot (~50m), last 24h ──
    try {
      final locSnap = await _db
          .collection('issues')
          .where('category', isEqualTo: category)
          .get();

      final locDup = locSnap.docs.any((doc) {
        final data = doc.data();
        final ts = data['created_at'] as int?;
        if (ts == null) return false;
        if (!DateTime.fromMillisecondsSinceEpoch(ts).isAfter(oneDayAgo)) {
          return false;
        }
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) return false;
        return (lat - latitude).abs() < 0.0005 &&
            (lng - longitude).abs() < 0.0005;
      });

      if (locDup) {
        return 'A similar issue has already been reported at this location recently.';
      }
    } catch (e) {
      debugPrint('Location dup check error: $e');
    }

    return null; // ✅ All checks passed
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
      // ── Image check ──
      if (imageFile == null) {
        return 'Please attach an image of the issue.';
      }

      // ── Run all fraud/spam/duplicate checks (skip for anonymous) ──
      if (!isAnonymous) {
        final blockReason = await _runAllChecks(
          userId: userId,
          description: description,
          latitude: latitude,
          longitude: longitude,
          category: category,
        );
        if (blockReason != null) {
          // Log to fraud_reports for admin review
          _db.collection('fraud_reports').add({
            'user_id': userId,
            'reason': blockReason,
            'description': description,
            'latitude': latitude,
            'longitude': longitude,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          }).catchError((_) {});
          return blockReason;
        }
      }

      // ── Upload image ──
      final imageUrl = await uploadImage(imageFile);
      if (imageUrl == null) {
        return 'Failed to upload image. Check internet connection.';
      }

      // ── Save issue to Firestore ──
      final priorityScore = isEmergency ? AppConstants.emergencyBoost : 1.0;
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

      // ── Update user stats ──
      if (!isAnonymous) {
        await _db.collection('users').doc(userId).set(
          {'issues_reported': FieldValue.increment(1)},
          SetOptions(merge: true),
        );
      }

      // ── Update city stats ──
      await _db.collection('city_stats').doc(city).set(
        {'issue_count': FieldValue.increment(1), 'city': city},
        SetOptions(merge: true),
      );

      return null; // ✅ Success
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
      final existingVote = await _db
          .collection('votes')
          .where('issue_id', isEqualTo: issueId)
          .where('user_id', isEqualTo: userId)
          .get();

      if (existingVote.docs.isNotEmpty) return false;

      final weight = trustScore.clamp(0.5, 3.0);

      await _db.collection('votes').add({
        'issue_id': issueId,
        'user_id': userId,
        'weight': weight,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      await _db.collection('issues').doc(issueId).update({
        'priority_score': FieldValue.increment(weight),
        'vote_count': FieldValue.increment(1),
      });

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
    final doc = await _db.collection('issues').doc(issueId).get();
    final city = doc.data()?['city'] as String?;

    await _db.collection('issues').doc(issueId).update({'status': status});

    if (status == 'resolved' && city != null) {
      await _db.collection('city_stats').doc(city).set(
        {'resolved': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    }

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
        data['resolved'] = data['resolved'] ?? 0;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('City stats error: $e');
      return [];
    }
  }
}
