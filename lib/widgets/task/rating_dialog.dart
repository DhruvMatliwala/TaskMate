import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../common/gradient_button.dart';

class RatingDialog extends StatefulWidget {
  final String workerName;
  final String taskTitle;
  final Function(double stars, String? comment) onSubmit;

  const RatingDialog({
    super.key,
    required this.workerName,
    required this.taskTitle,
    required this.onSubmit,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog>
    with SingleTickerProviderStateMixin {
  double _stars = 5.0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 36,
                ),
              ),

              const SizedBox(height: 20),

              // Title
              const Text(
                'Task Completed! 🎉',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                'How was your experience with ${widget.workerName}?',
                style: const TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Star rating
              RatingBar.builder(
                initialRating: _stars,
                minRating: 1,
                itemCount: 5,
                itemSize: 44,
                unratedColor: const Color(0xFF2D2D4E),
                itemBuilder: (context, _) => const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFD700),
                ),
                onRatingUpdate: (rating) {
                  setState(() => _stars = rating);
                },
              ),

              const SizedBox(height: 8),

              Text(
                _getRatingLabel(),
                style: TextStyle(
                  color: _getRatingColor(),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 20),

              // Comment field
              TextField(
                controller: _commentController,
                maxLines: 3,
                maxLength: 200,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Leave a comment (optional)...',
                  hintStyle: const TextStyle(color: Color(0xFF4A4A6A)),
                  counterStyle: const TextStyle(color: Color(0xFF4A4A6A)),
                  filled: true,
                  fillColor: const Color(0xFF0F0F1A),
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
                    borderSide: const BorderSide(
                      color: Color(0xFF6C63FF),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Submit button
              GradientButton(
                label: 'Submit Rating',
                isLoading: _isSubmitting,
                icon: Icons.send_rounded,
                onPressed: _isSubmitting ? null : _submit,
              ),

              const SizedBox(height: 12),

              // Skip
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Skip for now',
                  style: TextStyle(color: Color(0xFF4A4A6A), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRatingLabel() {
    if (_stars >= 5) return 'Excellent!';
    if (_stars >= 4) return 'Very Good';
    if (_stars >= 3) return 'Good';
    if (_stars >= 2) return 'Fair';
    return 'Poor';
  }

  Color _getRatingColor() {
    if (_stars >= 4) return const Color(0xFF43E97B);
    if (_stars >= 3) return const Color(0xFFFFD700);
    return const Color(0xFFFF6584);
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    await widget.onSubmit(
      _stars,
      _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
    );
    if (mounted) Navigator.pop(context);
  }
}

/// Show the rating dialog
Future<void> showRatingDialog({
  required BuildContext context,
  required String workerName,
  required String taskTitle,
  required Function(double, String?) onSubmit,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => RatingDialog(
      workerName: workerName,
      taskTitle: taskTitle,
      onSubmit: onSubmit,
    ),
  );
}
