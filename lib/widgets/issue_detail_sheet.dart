import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../models/issue_model.dart';

/// Bottom sheet showing full details of a selected issue.
/// Used both from map markers and issue list cards.
class IssueDetailSheet extends StatelessWidget {
  final IssueModel issue;
  final VoidCallback onClose;

  const IssueDetailSheet({
    super.key,
    required this.issue,
    required this.onClose,
  });

  String get _categoryIcon {
    final cat = AppConstants.categories.firstWhere(
      (c) => c['id'] == issue.category,
      orElse: () => {'icon': '📌', 'label': 'Other'},
    );
    return cat['icon'] as String;
  }

  String get _categoryLabel {
    final cat = AppConstants.categories.firstWhere(
      (c) => c['id'] == issue.category,
      orElse: () => {'icon': '📌', 'label': 'Other'},
    );
    return cat['label'] as String;
  }

  Color get _statusColor {
    switch (issue.status) {
      case 'resolved':
        return AppColors.success;
      case 'in_progress':
        return Colors.blue;
      default:
        return AppColors.warning;
    }
  }

  String get _statusLabel {
    switch (issue.status) {
      case 'resolved':
        return '✅ Resolved';
      case 'in_progress':
        return '🔧 In Progress';
      default:
        return '🕐 Pending Review';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Emergency banner
          if (issue.isEmergency)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: AppColors.emergency,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emergency, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '🚨 EMERGENCY ISSUE — HIGH PRIORITY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Text(_categoryIcon, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _categoryLabel,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '📍 ${issue.city}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Issue image
                if (issue.imageUrl != null && issue.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: issue.imageUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 180,
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Status + Priority row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: _statusColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        _statusLabel,
                        style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.trending_up,
                              size: 14, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Text(
                            'Priority: ${issue.priorityScore.toInt()}',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                if (issue.description.isNotEmpty) ...[
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    issue.description,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                ],

                // Info grid
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.person,
                      label: issue.isAnonymous
                          ? '🕵️ Anonymous'
                          : (issue.userName ?? 'Unknown'),
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.thumb_up,
                      label: '${issue.voteCount} votes',
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.schedule,
                      label: _timeAgo(issue.createdAt),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // GPS coordinates
                Row(
                  children: [
                    const Icon(Icons.gps_fixed, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${issue.latitude.toStringAsFixed(5)}, ${issue.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mins ago';
    return 'Just now';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
