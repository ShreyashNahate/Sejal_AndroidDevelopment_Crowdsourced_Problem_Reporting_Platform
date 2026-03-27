import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:geolocator/geolocator.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../services/issue_service.dart';
import '../../services/location_service.dart';

/// Screen for reporting a new civic issue.
/// Supports: camera, GPS, voice input, category selection, anonymous mode, emergency flag.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _picker = ImagePicker();

  // Voice input
  late stt.SpeechToText _speech;
  bool _isListening = false;

  // Form state
  File? _imageFile;
  Position? _position;
  String _selectedCategory = 'garbage';
  bool _isEmergency = false;
  bool _isAnonymous = false;
  bool _isSubmitting = false;
  bool _isLoadingLocation = false;
  String? _address;
  String _city = 'Unknown';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _getLocation();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  /// Fetch GPS location automatically on screen open
  Future<void> _getLocation() async {
    setState(() => _isLoadingLocation = true);

    final position = await LocationService.getCurrentPosition();
    if (position != null) {
      final address = await LocationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final city = await LocationService.getCityFromCoordinates(
        position.latitude,
        position.longitude,
      );
      setState(() {
        _position = position;
        _address = address;
        _city = city;
      });
    }

    setState(() => _isLoadingLocation = false);
  }

  /// Open camera to capture issue photo
  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (photo != null) {
      setState(() => _imageFile = File(photo.path));
    }
  }

  /// Pick from gallery as alternative
  Future<void> _pickFromGallery() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (photo != null) {
      setState(() => _imageFile = File(photo.path));
    }
  }

  /// Start/stop voice input using speech_to_text
  Future<void> _toggleVoice() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      bool available = await _speech.initialize(
        onError: (_) => setState(() => _isListening = false),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            // Set recognized text in description field
            _descController.text = result.recognizedWords;
            // Auto-detect category from speech
            _detectCategoryFromText(result.recognizedWords);
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        );
      } else {
        _showError('Voice not available on this device.');
      }
    }
  }

  /// Keyword-based category detection from text input
  void _detectCategoryFromText(String text) {
    final lower = text.toLowerCase();
    for (final cat in AppConstants.categories) {
      final keywords = cat['keywords'] as List<String>;
      if (keywords.any((kw) => lower.contains(kw))) {
        setState(() => _selectedCategory = cat['id'] as String);
        break;
      }
    }
  }

  /// Submit the issue report
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null) {
      _showError('Please take a photo of the issue.');
      return;
    }

    if (_position == null) {
      _showError('Location not available. Please enable GPS.');
      return;
    }

    setState(() => _isSubmitting = true);

    final auth = context.read<AuthService>();
    final issueService = context.read<IssueService>();

    final error = await issueService.submitIssue(
      imageFile: _imageFile,
      latitude: _position!.latitude,
      longitude: _position!.longitude,
      category: _selectedCategory,
      description: _descController.text.trim(),
      isEmergency: _isEmergency,
      isAnonymous: _isAnonymous,
      userId: auth.userId,
      userName: auth.userName,
      city: _city,
    );

    setState(() => _isSubmitting = false);

    if (error != null) {
      _showError(error);
    } else {
      _showSuccess();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.emergency,
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('✅ Issue Reported!'),
        content: const Text(
          'Thank you for reporting. The authorities will review your complaint. '
          'You can track it on the map.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to home
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Report Issue'),
        actions: [
          // Emergency toggle in appbar
          if (_isEmergency)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.emergency,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '🚨 EMERGENCY',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Photo Section ---
              _SectionTitle(title: '📷 Photo (Required)'),
              const SizedBox(height: 8),
              _PhotoSection(
                imageFile: _imageFile,
                onCamera: _takePhoto,
                onGallery: _pickFromGallery,
              ),
              const SizedBox(height: 20),

              // --- Location Section ---
              _SectionTitle(title: '📍 Location'),
              const SizedBox(height: 8),
              _LocationCard(
                isLoading: _isLoadingLocation,
                position: _position,
                address: _address,
                onRefresh: _getLocation,
              ),
              const SizedBox(height: 20),

              // --- Category Section ---
              _SectionTitle(title: '🏷️ Category'),
              const SizedBox(height: 8),
              _CategoryGrid(
                selected: _selectedCategory,
                onSelect: (cat) => setState(() => _selectedCategory = cat),
              ),
              const SizedBox(height: 20),

              // --- Description with Voice Input ---
              _SectionTitle(title: '📝 Description'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Describe the issue...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: _detectCategoryFromText,
                      validator: (val) => (val == null || val.isEmpty)
                          ? 'Please describe the issue'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Voice input button
                  GestureDetector(
                    onTap: _toggleVoice,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 56,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _isListening
                            ? AppColors.emergency
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isListening ? 'Stop' : 'Voice',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_isListening)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.fiber_manual_record,
                          color: AppColors.emergency, size: 12),
                      SizedBox(width: 4),
                      Text('Listening... speak now',
                          style: TextStyle(color: AppColors.emergency)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // --- Toggles: Anonymous & Emergency ---
              _ToggleCard(
                icon: Icons.person_off,
                title: 'Report Anonymously',
                subtitle: 'Your identity will be hidden from public',
                value: _isAnonymous,
                onChanged: (val) => setState(() => _isAnonymous = val),
                activeColor: AppColors.primary,
              ),
              const SizedBox(height: 8),
              _ToggleCard(
                icon: Icons.emergency,
                title: 'Emergency Mode 🚨',
                subtitle: 'Mark as urgent - gets higher priority (+50 points)',
                value: _isEmergency,
                onChanged: (val) => setState(() => _isEmergency = val),
                activeColor: AppColors.emergency,
              ),
              const SizedBox(height: 24),

              // --- Submit Button ---
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isEmergency ? AppColors.emergency : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isEmergency
                              ? '🚨 Submit Emergency Report'
                              : '📤 Submit Report',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Helper Widgets ---

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  final File? imageFile;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _PhotoSection({
    required this.imageFile,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: imageFile == null ? Colors.grey.shade300 : AppColors.primary,
          width: 2,
        ),
      ),
      child: imageFile != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(imageFile!, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onCamera,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child:
                          const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PhotoButton(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: onCamera,
                ),
                const SizedBox(width: 20),
                _PhotoButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: onGallery,
                ),
              ],
            ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PhotoButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final bool isLoading;
  final Position? position;
  final String? address;
  final VoidCallback onRefresh;

  const _LocationCard({
    required this.isLoading,
    required this.position,
    required this.address,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.emergency, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: isLoading
                ? const Text('Getting your location...')
                : position != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            address ?? 'Location detected',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${position!.latitude.toStringAsFixed(4)}, ${position!.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      )
                    : const Text(
                        'Location not available\nPlease enable GPS',
                        style: TextStyle(color: AppColors.warning),
                      ),
          ),
          IconButton(
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: isLoading ? null : onRefresh,
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final String selected;
  final Function(String) onSelect;

  const _CategoryGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: AppConstants.categories.map((cat) {
        final isSelected = selected == cat['id'];
        return GestureDetector(
          onTap: () => onSelect(cat['id'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade200,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(cat['icon'] as String,
                    style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  (cat['label'] as String).split('/').first,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;
  final Color activeColor;

  const _ToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: value ? activeColor.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? activeColor : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: value ? activeColor : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: value ? activeColor : AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: activeColor,
          ),
        ],
      ),
    );
  }
}
