/// Model representing a SmartCity user
class UserModel {
  final String id;
  final String name;
  final double trustScore; // Used for weighted voting
  final int issuesReported;
  final int votescast;
  final String city;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.trustScore,
    required this.issuesReported,
    required this.votescast,
    required this.city,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? 'Citizen',
      trustScore: (map['trust_score'] as num?)?.toDouble() ?? 1.0,
      issuesReported: (map['issues_reported'] as num?)?.toInt() ?? 0,
      votescast: (map['votes_cast'] as num?)?.toInt() ?? 0,
      city: map['city'] ?? 'Unknown',
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'trust_score': trustScore,
      'issues_reported': issuesReported,
      'votes_cast': votescast,
      'city': city,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Voting weight is based on trust score (1.0 = normal, 2.0 = double weight)
  double get votingWeight => trustScore.clamp(0.5, 3.0);
}
