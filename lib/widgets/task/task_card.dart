import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../../services/firestore_service.dart';
import '../common/glass_card.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  final double? userLat;
  final double? userLng;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.userLat,
    this.userLng,
  });

  Color get _statusColor {
    switch (task.status) {
      case TaskStatus.open:
        return const Color(0xFF43E97B);
      case TaskStatus.accepted:
        return const Color(0xFFFFD700);
      case TaskStatus.inProgress:
        return const Color(0xFF6C63FF);
      case TaskStatus.completed:
        return const Color(0xFF9E9E9E);
      case TaskStatus.cancelled:
        return const Color(0xFFFF6584);
    }
  }

  IconData get _statusIcon {
    switch (task.status) {
      case TaskStatus.open:
        return Icons.radio_button_unchecked;
      case TaskStatus.accepted:
        return Icons.handshake_outlined;
      case TaskStatus.inProgress:
        return Icons.directions_run;
      case TaskStatus.completed:
        return Icons.check_circle_outline;
      case TaskStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate distance if user location is available
    String? distanceText;
    if (userLat != null && userLng != null) {
      final dist = FirestoreService.calculateDistance(
        userLat!,
        userLng!,
        task.location.latitude,
        task.location.longitude,
      );
      distanceText = dist < 1
          ? '${(dist * 1000).round()}m away'
          : '${dist.toStringAsFixed(1)}km away';
    }

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task image or placeholder icon
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: task.imageUrl != null
                ? Image.network(
                    task.imageUrl!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),

          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + Status chip row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (task.isUrgent == true)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.bolt_rounded, color: Color(0xFFFF6584), size: 16),
                      ),
                    _StatusChip(
                      label: task.status.displayName,
                      color: _statusColor,
                      icon: _statusIcon,
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Category badge
                Row(
                  children: [
                    Icon(task.category.icon, color: task.category.color, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      task.category.displayName,
                      style: TextStyle(
                        color: task.category.color.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Description
                Text(
                  task.description,
                  style: const TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 12,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 10),

                // Bottom row: reward + location + distance
                Row(
                  children: [
                    // Reward / Budget Range
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        (task.isOpen == true)
                            ? '₹${task.minBudget.toStringAsFixed(0)}-${task.maxBudget.toStringAsFixed(0)}'
                            : '₹${task.reward.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Location
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF9E9E9E),
                            size: 13,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              task.locationName,
                              style: const TextStyle(
                                color: Color(0xFF9E9E9E),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Distance
                    if (distanceText != null)
                      Text(
                        distanceText,
                        style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
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

  Widget _buildPlaceholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2D2D4E)),
      ),
      child: const Icon(
        Icons.task_alt,
        color: Color(0xFF6C63FF),
        size: 28,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
