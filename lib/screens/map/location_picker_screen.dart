import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../constants/app_colors.dart';
import '../../services/location_service.dart';

/// Full-screen map where user can tap to pin a location manually.
/// Returns [PickedLocation] with lat, lng, address, city.
class LocationPickerScreen extends StatefulWidget {
  /// Optional initial position (from GPS). If null, defaults to India center.
  final LatLng? initialPosition;

  const LocationPickerScreen({super.key, this.initialPosition});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late final MapController _mapController;

  LatLng? _pickedLatLng;
  String _address = 'Tap on map to select location';
  String _city = 'Unknown';
  bool _isResolving = false; // true while reverse geocoding runs
  bool _isConfirming = false; // true while confirm button loading

  // Default center: India
  static const LatLng _defaultCenter = LatLng(20.5937, 78.9629);
  static const double _defaultZoom = 5.0;
  static const double _pickedZoom = 15.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // If GPS position passed in, pre-pin it
    if (widget.initialPosition != null) {
      _pickedLatLng = widget.initialPosition;
      _resolveAddress(widget.initialPosition!);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Called when user taps anywhere on the map
  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      _pickedLatLng = latLng;
      _address = 'Resolving address...';
      _city = 'Unknown';
    });
    _resolveAddress(latLng);
  }

  /// Reverse geocode the tapped coordinates
  Future<void> _resolveAddress(LatLng latLng) async {
    setState(() => _isResolving = true);

    final address = await LocationService.getAddressFromCoordinates(
      latLng.latitude,
      latLng.longitude,
    );
    final city = await LocationService.getCityFromCoordinates(
      latLng.latitude,
      latLng.longitude,
    );

    if (mounted) {
      setState(() {
        _address = address;
        _city = city;
        _isResolving = false;
      });
    }
  }

  /// Move map to user's current GPS location
  Future<void> _goToMyLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get GPS location')),
        );
      }
      return;
    }

    final latLng = LatLng(position.latitude, position.longitude);
    _mapController.move(latLng, _pickedZoom);

    setState(() {
      _pickedLatLng = latLng;
      _address = 'Resolving address...';
    });
    _resolveAddress(latLng);
  }

  /// Return picked location to previous screen
  void _confirmLocation() {
    if (_pickedLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please tap on the map to select a location')),
      );
      return;
    }

    Navigator.pop(
      context,
      PickedLocation(
        latitude: _pickedLatLng!.latitude,
        longitude: _pickedLatLng!.longitude,
        address: _address,
        city: _city,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = widget.initialPosition ?? _defaultCenter;
    final initialZoom =
        widget.initialPosition != null ? _pickedZoom : _defaultZoom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📍 Pick Location'),
        actions: [
          // GPS button in AppBar
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Use my GPS location',
            onPressed: _goToMyLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── MAP ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: initialZoom,
              onTap: _onMapTap, // user taps to pin
            ),
            children: [
              // OpenStreetMap tiles (free)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.smartcity.app',
              ),

              // Show pin marker only when location is picked
              if (_pickedLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pickedLatLng!,
                      width: 50,
                      height: 60,
                      child: const _PinMarker(),
                    ),
                  ],
                ),
            ],
          ),

          // ── CENTER CROSSHAIR HINT (before pick) ──
          if (_pickedLatLng == null)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 40, color: AppColors.primary),
                  SizedBox(height: 8),
                  _HintBubble(text: 'Tap anywhere to drop pin'),
                ],
              ),
            ),

          // ── BOTTOM PANEL: address + confirm ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomPanel(
              address: _address,
              city: _city,
              isResolving: _isResolving,
              isPicked: _pickedLatLng != null,
              onConfirm: _confirmLocation,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──

class _PinMarker extends StatelessWidget {
  const _PinMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: AppColors.emergency,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 22),
        ),
        // Pin tail
        Container(
          width: 3,
          height: 12,
          color: AppColors.emergency,
        ),
      ],
    );
  }
}

class _HintBubble extends StatelessWidget {
  final String text;
  const _HintBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final String address;
  final String city;
  final bool isResolving;
  final bool isPicked;
  final VoidCallback onConfirm;

  const _BottomPanel({
    required this.address,
    required this.city,
    required this.isResolving,
    required this.isPicked,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Address row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on,
                  color: AppColors.emergency, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: isResolving
                    ? const Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Getting address...',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            address,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (city != 'Unknown')
                            Text(
                              '🏙️ $city',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            ),
                        ],
                      ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isPicked ? onConfirm : null,
              icon: const Icon(Icons.check_circle),
              label: Text(
                isPicked ? 'Confirm This Location' : 'Tap map to select',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Data class returned to the calling screen
class PickedLocation {
  final double latitude;
  final double longitude;
  final String address;
  final String city;

  const PickedLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
  });
}
