import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/issue_service.dart';
import '../../widgets/issue_card.dart';

/// Main home screen with bottom navigation and quick stats
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize user and load issues after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final auth = context.read<AuthService>();
    final userService = context.read<UserService>();
    final issueService = context.read<IssueService>();

    await userService.loadUser(auth.userId, auth.userName, auth.city);
    await issueService.fetchIssues();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, '/report')
                  .then((_) => context.read<IssueService>().fetchIssues()),
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Report Issue'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _HomeTab();
      case 1:
        return _navigateTo('/map');
      case 2:
        return _navigateTo('/chatbot');
      case 3:
        return _navigateTo('/leaderboard');
      default:
        return _HomeTab();
    }
  }

  // Navigate and return placeholder (actual nav uses pushNamed)
  Widget _navigateTo(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamed(context, route);
      setState(() => _currentIndex = 0);
    });
    return _HomeTab();
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) {
        if (index == 0) {
          setState(() => _currentIndex = 0);
        } else if (index == 1) {
          Navigator.pushNamed(context, '/map');
        } else if (index == 2) {
          Navigator.pushNamed(context, '/chatbot');
        } else if (index == 3) {
          Navigator.pushNamed(context, '/leaderboard');
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
        NavigationDestination(icon: Icon(Icons.chat_bubble), label: 'Chatbot'),
        NavigationDestination(icon: Icon(Icons.leaderboard), label: 'Ranks'),
      ],
    );
  }
}

/// Home tab content with stats and recent issues
class _HomeTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final issueService = context.watch<IssueService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('🏙️ SmartCity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
            tooltip: 'My Profile',
          ),
          // Emergency button in top bar
          IconButton(
            icon: const Icon(Icons.emergency, color: AppColors.emergency),
            onPressed: () => Navigator.pushNamed(context, '/emergency'),
            tooltip: 'Emergency Mode',
          ),
          // Admin button
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () => Navigator.pushNamed(context, '/admin'),
            tooltip: 'Admin View',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => issueService.fetchIssues(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome card
              _WelcomeCard(auth: auth),
              const SizedBox(height: 16),

              // Stats row
              _StatsRow(issues: issueService.issues),
              const SizedBox(height: 20),

              // Emergency issues highlight
              if (issueService.emergencyIssues.isNotEmpty) ...[
                _SectionHeader(
                  title: '🚨 Emergency Issues',
                  color: AppColors.emergency,
                  onTap: () => Navigator.pushNamed(context, '/emergency'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: issueService.emergencyIssues.take(5).length,
                    itemBuilder: (ctx, i) => SizedBox(
                      width: 280,
                      child: IssueCard(
                        issue: issueService.emergencyIssues[i],
                        compact: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Recent issues
              _SectionHeader(
                title: '📋 Recent Issues',
                color: AppColors.primary,
                onTap: null,
              ),
              const SizedBox(height: 8),

              if (issueService.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (issueService.issues.isEmpty)
                _EmptyState()
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: issueService.issues.take(20).length,
                  itemBuilder: (ctx, i) => IssueCard(
                    issue: issueService.issues[i],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final AuthService auth;
  const _WelcomeCard({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Text(
              auth.userName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${auth.userName}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '📍 ${auth.city}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🏅 Active Citizen',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List issues;
  const _StatsRow({required this.issues});

  @override
  Widget build(BuildContext context) {
    final pending = issues.where((i) => i.status == 'pending').length;
    final resolved = issues.where((i) => i.status == 'resolved').length;
    final emergency = issues.where((i) => i.isEmergency).length;

    return Row(
      children: [
        _StatCard(
          label: 'Total',
          value: '${issues.length}',
          icon: Icons.report,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Pending',
          value: '$pending',
          icon: Icons.pending,
          color: AppColors.warning,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Resolved',
          value: '$resolved',
          icon: Icons.check_circle,
          color: AppColors.success,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Emergency',
          value: '$emergency',
          icon: Icons.emergency,
          color: AppColors.emergency,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback? onTap;

  const _SectionHeader({
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        if (onTap != null)
          TextButton(
            onPressed: onTap,
            child: const Text('See All →'),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.inbox, size: 60, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'No issues reported yet',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to report a civic issue!',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
