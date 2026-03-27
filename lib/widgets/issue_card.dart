import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../models/issue_model.dart';
import '../services/auth_service.dart';
import '../services/issue_service.dart';
import '../services/user_service.dart';
import '../widgets/issue_detail_sheet.dart';

/// Reusable card widget for displaying a civic issue.
/// Shows image, category, status, votes, and vote button.
class IssueCard extends StatelessWidget {
  final IssueModel issue;
  final bool compact; // compact = horizontal list style

  const IssueCard({super.key, required this.issue, this.compact = false});

  String get _categoryIcon {
    final cat = AppConstants.categories.firstWhere(
      (c) => c['id'] == issue.category,
      orElse: () => {'icon': '📌'},
    );
    return cat['icon'] as String;
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
        return '🕐 Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    return _buildFull(context);
  }

  Widget _buildFull(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Issue thumbnail
              _IssueThumbnail(imageUrl: issue.imageUrl, size: 80),
              const SizedBox(width: 12),

              // Issue info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category + Emergency badge
                    Row(
                      children: [
                        Text('$_categoryIcon ',
                            style: const TextStyle(fontSize: 16)),
                        Text(
                          issue.category.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        if (issue.isEmergency)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.emergency,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '🚨',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Description
                    Text(
                      issue.description.isEmpty
                          ? 'No description'
                          : issue.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),

                    // Footer: status + votes + reporter
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _statusLabel,
                            style: TextStyle(
                              color: _statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.thumb_up,
                            size: 12, color: AppColors.primary),
                        const SizedBox(width: 2),
                        Text(
                          '${issue.voteCount}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.primary),
                        ),
                        const Spacer(),
                        // Reporter name
                        Text(
                          issue.isAnonymous
                              ? '🕵️ Anonymous'
                              : (issue.userName ?? 'Unknown'),
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Location + time
                    Text(
                      '📍 ${issue.city}  •  ${_timeAgo(issue.createdAt)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // Vote button
              _VoteButton(issue: issue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context),
        child: SizedBox(
          width: 240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: _IssueThumbnail(
                    imageUrl: issue.imageUrl, size: 100, fullWidth: true),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('$_categoryIcon ',
                            style: const TextStyle(fontSize: 14)),
                        Text(
                          issue.category.toUpperCase(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const Spacer(),
                        if (issue.isEmergency)
                          const Text('🚨', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '📍 ${issue.city}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          IssueDetailSheet(issue: issue, onClose: () => Navigator.pop(context)),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

/// Thumbnail image widget with fallback
class _IssueThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final bool fullWidth;

  const _IssueThumbnail({
    required this.imageUrl,
    required this.size,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget image;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      image = CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    } else {
      image = _placeholder();
    }

    if (fullWidth) {
      return SizedBox(height: size, width: double.infinity, child: image);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: size, height: size, child: image),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade100,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, color: Colors.grey),
          SizedBox(height: 4),
          Text('No Image', style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

/// Thumbs-up vote button with trust-weighted voting
class _VoteButton extends StatefulWidget {
  final IssueModel issue;
  const _VoteButton({required this.issue});

  @override
  State<_VoteButton> createState() => _VoteButtonState();
}

class _VoteButtonState extends State<_VoteButton> {
  bool _voted = false;
  bool _loading = false;

  Future<void> _vote() async {
    if (_voted || _loading) return;

    setState(() => _loading = true);

    final auth = context.read<AuthService>();
    final userService = context.read<UserService>();
    final issueService = context.read<IssueService>();

    final success = await issueService.voteOnIssue(
      issueId: widget.issue.id,
      userId: auth.userId,
      trustScore: userService.trustScore,
    );

    if (success) {
      setState(() => _voted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Vote submitted! Priority updated.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already voted on this issue.'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _vote,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _voted
                  ? AppColors.primary.withOpacity(0.15)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _voted ? Icons.thumb_up : Icons.thumb_up_outlined,
                    color: _voted ? AppColors.primary : Colors.grey,
                    size: 20,
                  ),
          ),
        ),
        Text(
          '${widget.issue.voteCount + (_voted ? 1 : 0)}',
          style: TextStyle(
            fontSize: 11,
            color: _voted ? AppColors.primary : Colors.grey,
            fontWeight: _voted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
