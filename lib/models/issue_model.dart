/// Model representing a civic issue report
class IssueModel {
  final String id;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final String category;
  final String description;
  final String status;
  final bool isEmergency;
  final bool isAnonymous;
  final String? userId; // null if anonymous
  final String? userName; // null if anonymous
  final double priorityScore;
  final int voteCount;
  final DateTime createdAt;
  final String city;

  const IssueModel({
    required this.id,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.description,
    required this.status,
    required this.isEmergency,
    required this.isAnonymous,
    this.userId,
    this.userName,
    required this.priorityScore,
    required this.voteCount,
    required this.createdAt,
    required this.city,
  });

  /// Convert Firestore document to IssueModel
  factory IssueModel.fromMap(Map<String, dynamic> map, String id) {
    return IssueModel(
      id: id,
      imageUrl: map['image_url'],
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      category: map['category'] ?? 'other',
      description: map['description'] ?? '',
      status: map['status'] ?? 'pending',
      isEmergency: map['is_emergency'] ?? false,
      isAnonymous: map['is_anonymous'] ?? false,
      userId: map['user_id'],
      userName: map['user_name'],
      priorityScore: (map['priority_score'] as num?)?.toDouble() ?? 0.0,
      voteCount: (map['vote_count'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : DateTime.now(),
      city: map['city'] ?? 'Unknown',
    );
  }

  /// Convert IssueModel to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'image_url': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'description': description,
      'status': status,
      'is_emergency': isEmergency,
      'is_anonymous': isAnonymous,
      'user_id': isAnonymous ? null : userId,
      'user_name': isAnonymous ? 'Anonymous' : userName,
      'priority_score': priorityScore,
      'vote_count': voteCount,
      'created_at': createdAt.millisecondsSinceEpoch,
      'city': city,
    };
  }

  /// Create a copy with updated fields
  IssueModel copyWith({
    String? imageUrl,
    String? status,
    double? priorityScore,
    int? voteCount,
    bool? isEmergency,
  }) {
    return IssueModel(
      id: id,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude,
      longitude: longitude,
      category: category,
      description: description,
      status: status ?? this.status,
      isEmergency: isEmergency ?? this.isEmergency,
      isAnonymous: isAnonymous,
      userId: userId,
      userName: userName,
      priorityScore: priorityScore ?? this.priorityScore,
      voteCount: voteCount ?? this.voteCount,
      createdAt: createdAt,
      city: city,
    );
  }
}
