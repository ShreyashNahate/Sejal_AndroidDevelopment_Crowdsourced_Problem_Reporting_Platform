import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/issue_model.dart';
import '../../services/issue_service.dart';
import '../../widgets/issue_detail_sheet.dart';

/// Map screen showing all reported issues on OpenStreetMap.
/// Red markers = normal issues, Flashing red = emergency issues.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  // Default center: India
  static const LatLng _defaultCenter = LatLng(19.9975, 73.7898); // Nashik
  double _zoom = 12.0;

  String? _filterCategory;
  bool _showEmergencyOnly = false;
  IssueModel? _selectedIssue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IssueService>().fetchIssues();
    });
  }

  List<IssueModel> _getFilteredIssues(List<IssueModel> issues) {
    return issues.where((issue) {
      if (_showEmergencyOnly && !issue.isEmergency) return false;
      if (_filterCategory != null && issue.category != _filterCategory)
        return false;
      return true;
    }).toList();
  }

  Color _markerColor(IssueModel issue) {
    if (issue.isEmergency) return AppColors.emergency;
    switch (issue.status) {
      case AppConstants.statusResolved:
        return AppColors.success;
      case AppConstants.statusInProgress:
        return AppColors.warning;
      default:
        return AppColors.markerNormal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final issueService = context.watch<IssueService>();
    final filtered = _getFilteredIssues(issueService.issues);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🗺️ Issues Map'),
        actions: [
          // Emergency toggle
          IconButton(
            icon: Icon(
              Icons.emergency,
              color: _showEmergencyOnly ? AppColors.emergency : Colors.white,
            ),
            onPressed: () =>
                setState(() => _showEmergencyOnly = !_showEmergencyOnly),
            tooltip: 'Show Emergency Only',
          ),
          // Filter by category
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showCategoryFilter,
            tooltip: 'Filter by Category',
          ),
        ],
      ),
      body: Stack(
        children: [
          // OpenStreetMap using flutter_map (free, no API key needed)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: _zoom,
              onTap: (_, __) => setState(() => _selectedIssue = null),
            ),
            children: [
              // OSM tile layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.smartcity.app',
              ),
              // Issue markers
              MarkerLayer(
                markers: filtered.map((issue) {
                  return Marker(
                    point: LatLng(issue.latitude, issue.longitude),
                    width: issue.isEmergency ? 50 : 40,
                    height: issue.isEmergency ? 50 : 40,
                    child: GestureDetector(
                      onTap: () => _onMarkerTap(issue),
                      child: _IssueMarker(
                        issue: issue,
                        color: _markerColor(issue),
                        isSelected: _selectedIssue?.id == issue.id,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Active filter chip
          if (_filterCategory != null || _showEmergencyOnly)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _FilterBar(
                category: _filterCategory,
                emergencyOnly: _showEmergencyOnly,
                onClear: () => setState(() {
                  _filterCategory = null;
                  _showEmergencyOnly = false;
                }),
              ),
            ),

          // Issue count
          Positioned(
            bottom: _selectedIssue != null ? 260 : 20,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${filtered.length} issues',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),

          // Map legend
          Positioned(
            bottom: _selectedIssue != null ? 260 : 20,
            left: 16,
            child: const _MapLegend(),
          ),

          // Selected issue detail bottom sheet
          if (_selectedIssue != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IssueDetailSheet(
                issue: _selectedIssue!,
                onClose: () => setState(() => _selectedIssue = null),
              ),
            ),
        ],
      ),
    );
  }

  void _onMarkerTap(IssueModel issue) {
    setState(() => _selectedIssue = issue);
    // Center map on selected issue
    _mapController.move(
      LatLng(issue.latitude, issue.longitude),
      14.0,
    );
  }

  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filterCategory == null,
                  onSelected: (_) {
                    setState(() => _filterCategory = null);
                    Navigator.pop(context);
                  },
                ),
                ...AppConstants.categories.map((cat) => FilterChip(
                      avatar: Text(cat['icon'] as String),
                      label: Text(cat['label'] as String),
                      selected: _filterCategory == cat['id'],
                      onSelected: (_) {
                        setState(() => _filterCategory = cat['id'] as String);
                        Navigator.pop(context);
                      },
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom map marker widget
class _IssueMarker extends StatelessWidget {
  final IssueModel issue;
  final Color color;
  final bool isSelected;

  const _IssueMarker({
    required this.issue,
    required this.color,
    required this.isSelected,
  });

  String get _icon {
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? color : color.withOpacity(0.85),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: isSelected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: isSelected ? 12 : 6,
            spreadRadius: isSelected ? 2 : 0,
          ),
        ],
      ),
      child: Center(
        child: Text(
          _icon,
          style: TextStyle(fontSize: issue.isEmergency ? 20 : 16),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String? category;
  final bool emergencyOnly;
  final VoidCallback onClear;

  const _FilterBar({
    required this.category,
    required this.emergencyOnly,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.filter_list, size: 16),
          const SizedBox(width: 4),
          Text(
            emergencyOnly ? '🚨 Emergency Only' : 'Category: $category',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendItem(color: AppColors.emergency, label: 'Emergency'),
          SizedBox(height: 4),
          _LegendItem(color: AppColors.markerNormal, label: 'Pending'),
          SizedBox(height: 4),
          _LegendItem(color: AppColors.warning, label: 'In Progress'),
          SizedBox(height: 4),
          _LegendItem(color: AppColors.success, label: 'Resolved'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
