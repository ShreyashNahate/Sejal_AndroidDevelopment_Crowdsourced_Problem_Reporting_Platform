import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../services/issue_service.dart';

/// Leaderboard screen showing city rankings by issue count.
/// Gamifies civic participation by ranking cities.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> _cityStats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final issueService = context.read<IssueService>();
    final stats = await issueService.getCityStats();

    // If Firebase has no data yet, use demo data
    if (stats.isEmpty) {
      _cityStats = _demoData();
    } else {
      _cityStats = stats;
    }

    setState(() => _isLoading = false);
  }

  /// Demo data for testing without Firebase data
  List<Map<String, dynamic>> _demoData() {
    return [
      {'city': 'Mumbai', 'issue_count': 342, 'resolved': 198},
      {'city': 'Delhi', 'issue_count': 289, 'resolved': 145},
      {'city': 'Bengaluru', 'issue_count': 234, 'resolved': 167},
      {'city': 'Pune', 'issue_count': 198, 'resolved': 134},
      {'city': 'Nashik', 'issue_count': 156, 'resolved': 98},
      {'city': 'Chennai', 'issue_count': 145, 'resolved': 89},
      {'city': 'Hyderabad', 'issue_count': 134, 'resolved': 78},
      {'city': 'Kolkata', 'issue_count': 123, 'resolved': 67},
      {'city': 'Ahmedabad', 'issue_count': 112, 'resolved': 56},
      {'city': 'Jaipur', 'issue_count': 98, 'resolved': 45},
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('🏆 City Leaderboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: CustomScrollView(
                slivers: [
                  // Header section with top 3 podium
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        _LeaderboardHeader(),
                        const SizedBox(height: 8),
                        if (_cityStats.length >= 3)
                          _PodiumSection(
                              topCities: _cityStats.take(3).toList()),
                        const SizedBox(height: 16),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '📊 All Cities Ranking',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  // Full city list
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _CityRankCard(
                        rank: i + 1,
                        data: _cityStats[i],
                      ),
                      childCount: _cityStats.length,
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
    );
  }
}

class _LeaderboardHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Text('🏆', style: TextStyle(fontSize: 40)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'City Rankings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Cities ranked by civic issue reporting activity',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Top 3 cities podium display
class _PodiumSection extends StatelessWidget {
  final List<Map<String, dynamic>> topCities;
  const _PodiumSection({required this.topCities});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          if (topCities.length > 1)
            _PodiumItem(
              rank: 2,
              city: topCities[1]['city'] as String,
              count: topCities[1]['issue_count'] as int,
              height: 70,
              color: const Color(0xFFC0C0C0),
              emoji: '🥈',
            ),
          // 1st place (tallest)
          _PodiumItem(
            rank: 1,
            city: topCities[0]['city'] as String,
            count: topCities[0]['issue_count'] as int,
            height: 100,
            color: const Color(0xFFFFD700),
            emoji: '🥇',
          ),
          // 3rd place
          if (topCities.length > 2)
            _PodiumItem(
              rank: 3,
              city: topCities[2]['city'] as String,
              count: topCities[2]['issue_count'] as int,
              height: 50,
              color: const Color(0xFFCD7F32),
              emoji: '🥉',
            ),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  final int rank;
  final String city;
  final int count;
  final double height;
  final Color color;
  final String emoji;

  const _PodiumItem({
    required this.rank,
    required this.city,
    required this.count,
    required this.height,
    required this.color,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          city,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          '$count issues',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// City rank card for the full list
class _CityRankCard extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> data;

  const _CityRankCard({required this.rank, required this.data});

  @override
  Widget build(BuildContext context) {
    final city = data['city'] as String? ?? 'Unknown';
    final count = data['issue_count'] as int? ?? 0;
    final resolved = data['resolved'] as int? ?? 0;
    final resolutionRate = count > 0 ? (resolved / count * 100).toInt() : 0;

    Color rankColor = AppColors.textSecondary;
    if (rank == 1) rankColor = const Color(0xFFFFD700);
    if (rank == 2) rankColor = const Color(0xFFC0C0C0);
    if (rank == 3) rankColor = const Color(0xFFCD7F32);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: rank <= 3
            ? Border.all(color: rankColor.withOpacity(0.5), width: 2)
            : null,
      ),
      child: Row(
        children: [
          // Rank number
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // City info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                // Resolution progress bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: resolutionRate / 100,
                          backgroundColor: Colors.grey.shade200,
                          color: AppColors.success,
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$resolutionRate% resolved',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Issue count
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const Text(
                'issues',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
