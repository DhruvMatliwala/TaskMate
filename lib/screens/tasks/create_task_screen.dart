import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/places_service.dart';
import '../../services/pricing_service.dart';
import '../../services/directions_service.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/glass_card.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _rewardController = TextEditingController();
  final _locationController = TextEditingController();

  // Task Details
  JobCategory _selectedCategory = JobCategory.delivery;
  bool _isUrgent = false;

  // Image
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  // Location
  double? _selectedLat;
  double? _selectedLng;
  final PlacesService _placesService = PlacesService();
  List<PlaceSuggestion> _suggestions = [];
  bool _showSuggestions = false;
  String? _sessionToken;

  // Pricing
  double _suggestedReward = 0;
  double _minBudget = 0;
  double _maxBudget = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _rewardController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _updatePricing() {
    if (_selectedLat == null) return;

    final locProv = context.read<LocationProvider>();
    final userLatLng = locProv.currentLatLng;
    final destLatLng = LatLng(_selectedLat!, _selectedLng!);

    // Calculate distance
    final distance = DirectionsService.getDistanceKm(userLatLng, destLatLng);

    final range = PricingService.calculateBudgetRange(
      category: _selectedCategory,
      distanceKm: distance,
      isUrgent: _isUrgent,
    );

    setState(() {
      _suggestedReward = range.suggested;
      _minBudget = range.min;
      _maxBudget = range.max;
      // We don't need _rewardController for input anymore, 
      // but we'll use it to store the final submitted value if needed.
    });
  }

  // ── Image Picker ──────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
    if (mounted) Navigator.pop(context);
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D4E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Upload Task Photo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ImageSourceButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Camera',
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImageSourceButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Location Search ───────────────────────────────────────────────────────

  Future<void> _onLocationChanged(String value) async {
    if (value.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    _sessionToken ??= const Uuid().v4();
    final results = await _placesService.getAutocompleteSuggestions(
      value,
      sessionToken: _sessionToken,
    );

    if (mounted) {
      setState(() {
        _suggestions = results;
        _showSuggestions = results.isNotEmpty;
      });
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    _locationController.text = suggestion.description;
    setState(() => _showSuggestions = false);

    final details = await _placesService.getPlaceDetails(
      suggestion.placeId,
      sessionToken: _sessionToken,
    );
    _sessionToken = null;

    if (details != null) {
      setState(() {
        _selectedLat = details.lat;
        _selectedLng = details.lng;
      });
      _updatePricing();
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLat == null || _selectedLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a location from the suggestions'),
        ),
      );
      return;
    }

    final user = context.read<AuthProvider>().userModel!;
    final taskProv = context.read<TaskProvider>();

    final taskId = await taskProv.createTask(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      lat: _selectedLat!,
      lng: _selectedLng!,
      locationName: _locationController.text.trim(),
      minBudget: _minBudget,
      maxBudget: _maxBudget,
      category: _selectedCategory,
      isUrgent: _isUrgent,
      creator: user,
      imageFile: _imageBytes,
    );

    if (mounted) {
      if (taskId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF43E97B)),
                SizedBox(width: 8),
                Text('Task posted successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else {
        // Show the actual error so the developer can diagnose it
        final err = taskProv.errorMessage ?? 'Unknown error — check the console.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFFF6584)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    err,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2D1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: const CustomAppBar(title: 'Post a Task'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image uploader ─────────────────────────────────────────────
              const _SectionLabel(label: 'Task Photo (Optional)'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _showImagePicker,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _imageBytes != null
                          ? const Color(0xFF6C63FF)
                          : const Color(0xFF2D2D4E),
                      width: _imageBytes != null ? 2 : 1,
                    ),
                  ),
                  child: _imageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(_imageBytes!, fit: BoxFit.cover),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setState(() => _imageBytes = null),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Color(0xFF6C63FF),
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Tap to add a photo',
                              style: TextStyle(
                                color: Color(0xFF9E9E9E),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Text(
                              'Helps workers understand the task',
                              style: TextStyle(
                                color: Color(0xFF4A4A6A),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Category Selection ─────────────────────────────────────────
              const _SectionLabel(label: 'Task Category'),
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                borderRadius: 14,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<JobCategory>(
                    value: _selectedCategory,
                    dropdownColor: const Color(0xFF1A1A2E),
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6C63FF)),
                    onChanged: (JobCategory? newValue) {
                      if (newValue != null) {
                        setState(() => _selectedCategory = newValue);
                        _updatePricing();
                      }
                    },
                    items: JobCategory.values.map((JobCategory category) {
                      return DropdownMenuItem<JobCategory>(
                        value: category,
                        child: Row(
                          children: [
                            Icon(category.icon, color: category.color, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              category.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Urgent Switch ──────────────────────────────────────────────
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                borderRadius: 14,
                borderColor: _isUrgent ? const Color(0xFFFF6584).withValues(alpha: 0.5) : null,
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Color(0xFFFF6584), size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Urgent Task',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          Text(
                            'Attract workers faster with +25% reward',
                            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isUrgent,
                      activeColor: const Color(0xFFFF6584),
                      onChanged: (val) {
                        setState(() => _isUrgent = val);
                        _updatePricing();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Task Title ─────────────────────────────────────────────────
              const _SectionLabel(label: 'Task Title *'),
              const SizedBox(height: 8),
              _buildField(
                controller: _titleController,
                hint: 'e.g. Help me move furniture',
                icon: Icons.title,
                maxLength: 80,
                validator: (v) => (v == null || v.trim().length < 5)
                    ? 'Title must be at least 5 characters'
                    : null,
              ),

              const SizedBox(height: 20),

              // ── Description ────────────────────────────────────────────────
              const _SectionLabel(label: 'Description *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                maxLength: 500,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                validator: (v) => (v == null || v.trim().length < 20)
                    ? 'Description must be at least 20 characters'
                    : null,
                decoration: _fieldDecoration(
                  hint: 'Describe the task in detail — what needs to be done, any tools required, etc.',
                  icon: Icons.description_outlined,
                ),
              ),

              const SizedBox(height: 20),

              // ── Location search ────────────────────────────────────────────
              const _SectionLabel(label: 'Task Location *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                onChanged: _onLocationChanged,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                validator: (v) =>
                    (v == null || v.trim().isEmpty || _selectedLat == null)
                        ? 'Please select a location from suggestions'
                        : null,
                decoration: _fieldDecoration(
                  hint: 'Search for a location...',
                  icon: Icons.location_on_outlined,
                  suffix: _selectedLat != null
                      ? const Icon(
                          Icons.check_circle,
                          color: Color(0xFF43E97B),
                          size: 20,
                        )
                      : null,
                ),
              ),

              // Suggestions
              if (_showSuggestions)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2D2D4E)),
                  ),
                  child: Column(
                    children: _suggestions.map((s) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: Color(0xFF6C63FF),
                          size: 18,
                        ),
                        title: Text(
                          s.mainText,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        subtitle: Text(
                          s.secondaryText,
                          style: const TextStyle(
                            color: Color(0xFF9E9E9E),
                            fontSize: 11,
                          ),
                        ),
                        onTap: () => _selectSuggestion(s),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 20),

              // ── Budget Range ──────────────────────────────────────────────
              const _SectionLabel(label: 'Task Budget Range'),
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Market Estimate',
                          style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
                        ),
                        if (_selectedLat != null)
                          Text(
                            '₹${_minBudget.toStringAsFixed(0)} - ₹${_maxBudget.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          )
                        else
                          const Text(
                            'Set location to see',
                            style: TextStyle(color: Color(0xFF4A4A6A), fontSize: 13),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF6C63FF), size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Workers will bid within or near this range based on their effort.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Submit ─────────────────────────────────────────────────────
              Consumer<TaskProvider>(
                builder: (_, taskProv, __) => GradientButton(
                  label: 'Post Task',
                  isLoading: taskProv.isLoading,
                  icon: Icons.publish_rounded,
                  onPressed: _submit,
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int? maxLength,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: _fieldDecoration(hint: hint, icon: icon, suffix: suffix),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF3A3A5A), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF4A4A6A), size: 20),
      suffixIcon: suffix,
      counterStyle: const TextStyle(color: Color(0xFF4A4A6A)),
      filled: true,
      fillColor: const Color(0xFF1A1A2E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2D2D4E)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2D2D4E)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF6584)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF6584), width: 1.5),
      ),
      errorStyle: const TextStyle(color: Color(0xFFFF6584)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }
}

class _ImageSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2D2D4E)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF6C63FF), size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
