/// Model representing a vote on an issue
class VoteModel {
  final String id;
  final String issueId;
  final String userId;
  final double weight; // Trust-based weight
  final DateTime createdAt;

  const VoteModel({
    required this.id,
    required this.issueId,
    required this.userId,
    required this.weight,
    required this.createdAt,
  });

  factory VoteModel.fromMap(Map<String, dynamic> map, String id) {
    return VoteModel(
      id: id,
      issueId: map['issue_id'] ?? '',
      userId: map['user_id'] ?? '',
      weight: (map['weight'] as num?)?.toDouble() ?? 1.0,
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'issue_id': issueId,
      'user_id': userId,
      'weight': weight,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}
