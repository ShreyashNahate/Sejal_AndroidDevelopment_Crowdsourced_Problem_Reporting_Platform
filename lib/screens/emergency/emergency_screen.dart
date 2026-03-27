import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/issue_model.dart';
import '../../services/issue_service.dart';
import '../../widgets/issue_card.dart';

/// Emergency screen showing only emergency-flagged issues.
/// Also provides quick dial to emergency services.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  Future<void> _callNumber(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issueService = context.watch<IssueService>();
    final emergencyIssues = issueService.emergencyIssues;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3F3),
      appBar: AppBar(
        backgroundColor: AppColors.emergency,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emergency, color: Colors.white),
            SizedBox(width: 8),
            Text('Emergency Mode'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Emergency banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.emergency,
            child: Column(
              children: [
                const Text(
                  '🚨 EMERGENCY ISSUES',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${emergencyIssues.length} active emergency reports',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          // Quick dial emergency services
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📞 Quick Emergency Dial',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _EmergencyDial(
                      label: 'Police',
                      number: '100',
                      icon: '👮',
                      color: Colors.blue,
                      onTap: () => _callNumber('100'),
                    ),
                    _EmergencyDial(
                      label: 'Ambulance',
                      number: '108',
                      icon: '🚑',
                      color: AppColors.emergency,
                      onTap: () => _callNumber('108'),
                    ),
                    _EmergencyDial(
                      label: 'Fire',
                      number: '101',
                      icon: '🚒',
                      color: Colors.orange,
                      onTap: () => _callNumber('101'),
                    ),
                    _EmergencyDial(
                      label: 'Disaster',
                      number: '1078',
                      icon: '🆘',
                      color: Colors.purple,
                      onTap: () => _callNumber('1078'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Emergency issues list
          Expanded(
            child: emergencyIssues.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle,
                            size: 60, color: AppColors.success),
                        const SizedBox(height: 12),
                        const Text(
                          'No Active Emergencies',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'All clear! No emergency reports at this time.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/report'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emergency,
                          ),
                          child: const Text(
                            '🚨 Report Emergency',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: emergencyIssues.length,
                    itemBuilder: (ctx, i) => _EmergencyIssueCard(
                      issue: emergencyIssues[i],
                    ),
                  ),
          ),
        ],
      ),
      // FAB to report new emergency
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/report'),
        backgroundColor: AppColors.emergency,
        icon: const Icon(Icons.add),
        label: const Text('Report Emergency'),
      ),
    );
  }
}

class _EmergencyDial extends StatelessWidget {
  final String label;
  final String number;
  final String icon;
  final Color color;
  final VoidCallback onTap;

  const _EmergencyDial({
    required this.label,
    required this.number,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
          Text(
            number,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Special emergency issue card with pulsing border
class _EmergencyIssueCard extends StatelessWidget {
  final IssueModel issue;
  const _EmergencyIssueCard({required this.issue});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.emergency, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.emergency.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
          )
        ],
      ),
      child: IssueCard(issue: issue),
    );
  }
}
