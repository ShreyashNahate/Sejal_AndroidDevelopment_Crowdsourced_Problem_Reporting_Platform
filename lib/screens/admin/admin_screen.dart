import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/issue_model.dart';
import '../../services/issue_service.dart';

/// Admin panel for viewing and managing all reported issues.
/// Sort by priority, filter by status, update issue status.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _filterStatus = 'all';
  bool _emergencyFirst = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IssueService>().fetchIssues();
    });
  }

  List<IssueModel> _getSortedIssues(List<IssueModel> issues) {
    List<IssueModel> filtered = issues;

    // Filter by status
    if (_filterStatus != 'all') {
      filtered = filtered.where((i) => i.status == _filterStatus).toList();
    }

    // Sort: emergency first (if enabled), then by priority score
    filtered.sort((a, b) {
      if (_emergencyFirst) {
        if (a.isEmergency && !b.isEmergency) return -1;
        if (!a.isEmergency && b.isEmergency) return 1;
      }
      return b.priorityScore.compareTo(a.priorityScore);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final issueService = context.watch<IssueService>();
    final sorted = _getSortedIssues(issueService.issues);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('⚙️ Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => issueService.fetchIssues(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Admin stats bar
          _AdminStatsBar(issues: issueService.issues),

          // Filter & sort toolbar
          _FilterToolbar(
            filterStatus: _filterStatus,
            emergencyFirst: _emergencyFirst,
            onFilterChange: (val) => setState(() => _filterStatus = val),
            onEmergencyToggle: (val) => setState(() => _emergencyFirst = val),
          ),

          // Issue list
          Expanded(
            child: issueService.isLoading
                ? const Center(child: CircularProgressIndicator())
                : sorted.isEmpty
                    ? const Center(
                        child: Text('No issues found'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: sorted.length,
                        itemBuilder: (ctx, i) => _AdminIssueCard(
                          issue: sorted[i],
                          onStatusChange: (status) async {
                            await issueService.updateStatus(
                              sorted[i].id,
                              status,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _AdminStatsBar extends StatelessWidget {
  final List<IssueModel> issues;
  const _AdminStatsBar({required this.issues});

  @override
  Widget build(BuildContext context) {
    final pending = issues.where((i) => i.status == 'pending').length;
    final inProgress = issues.where((i) => i.status == 'in_progress').length;
    final resolved = issues.where((i) => i.status == 'resolved').length;
    final emergency = issues.where((i) => i.isEmergency).length;

    return Container(
      color: AppColors.primaryDark,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(
              label: 'Total', value: '${issues.length}', color: Colors.white),
          _StatChip(
              label: 'Pending', value: '$pending', color: AppColors.warning),
          _StatChip(
              label: 'Progress',
              value: '$inProgress',
              color: Colors.blue.shade200),
          _StatChip(
              label: 'Resolved',
              value: '$resolved',
              color: Colors.green.shade300),
          _StatChip(
              label: '🚨 Urgent',
              value: '$emergency',
              color: AppColors.emergency),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }
}

class _FilterToolbar extends StatelessWidget {
  final String filterStatus;
  final bool emergencyFirst;
  final Function(String) onFilterChange;
  final Function(bool) onEmergencyToggle;

  const _FilterToolbar({
    required this.filterStatus,
    required this.emergencyFirst,
    required this.onFilterChange,
    required this.onEmergencyToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Status filter
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: filterStatus == 'all',
                    onTap: () => onFilterChange('all'),
                  ),
                  _FilterChip(
                    label: 'Pending',
                    selected: filterStatus == 'pending',
                    onTap: () => onFilterChange('pending'),
                    color: AppColors.warning,
                  ),
                  _FilterChip(
                    label: 'In Progress',
                    selected: filterStatus == 'in_progress',
                    onTap: () => onFilterChange('in_progress'),
                    color: Colors.blue,
                  ),
                  _FilterChip(
                    label: 'Resolved',
                    selected: filterStatus == 'resolved',
                    onTap: () => onFilterChange('resolved'),
                    color: AppColors.success,
                  ),
                ],
              ),
            ),
          ),
          // Emergency first toggle
          Row(
            children: [
              const Text('🚨', style: TextStyle(fontSize: 14)),
              Switch(
                value: emergencyFirst,
                onChanged: onEmergencyToggle,
                activeColor: AppColors.emergency,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? color : Colors.grey.shade300),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade600,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// Admin issue card with status update controls
class _AdminIssueCard extends StatelessWidget {
  final IssueModel issue;
  final Function(String) onStatusChange;

  const _AdminIssueCard({required this.issue, required this.onStatusChange});

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
        return 'Resolved';
      case 'in_progress':
        return 'In Progress';
      default:
        return 'Pending';
    }
  }

  String get _categoryIcon {
    switch (issue.category) {
      case 'garbage':
        return '🗑️';
      case 'water':
        return '💧';
      case 'road':
        return '🛣️';
      case 'electricity':
        return '⚡';
      case 'tree':
        return '🌳';
      default:
        return '📌';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: issue.isEmergency
            ? Border.all(color: AppColors.emergency, width: 2)
            : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Category icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      Text(_categoryIcon, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 10),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (issue.isEmergency)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: AppColors.emergency,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '🚨 EMERGENCY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          Text(
                            issue.category.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        issue.description.isEmpty
                            ? 'No description'
                            : issue.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                // Priority score badge
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '⬆️ ${issue.priorityScore.toInt()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'priority',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Footer row with status controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Location info
                Expanded(
                  child: Text(
                    '📍 ${issue.city} • ${issue.voteCount} votes',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),

                // Status update dropdown
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: onStatusChange,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'pending',
                      child: Row(
                        children: [
                          Icon(Icons.pending, color: Colors.orange, size: 16),
                          SizedBox(width: 8),
                          Text('Mark Pending'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'in_progress',
                      child: Row(
                        children: [
                          Icon(Icons.engineering, color: Colors.blue, size: 16),
                          SizedBox(width: 8),
                          Text('Mark In Progress'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'resolved',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green, size: 16),
                          SizedBox(width: 8),
                          Text('Mark Resolved'),
                        ],
                      ),
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
}
