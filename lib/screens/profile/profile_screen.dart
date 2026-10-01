import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/gradient_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: const CustomAppBar(
        title: 'Profile',
        showBackButton: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
          children: [
            const SizedBox(height: 16),

            // ── Avatar + name + role ────────────────────────────────────────
            Stack(
              alignment: Alignment.center,
              children: [
                // Glow ring
                Container(
                  width: 108,
                  height: 108,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Color(0xFF6C63FF),
                        Color(0xFFFF6584),
                        Color(0xFF43E97B),
                        Color(0xFF6C63FF),
                      ],
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF1A1A2E),
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 36,
                          ),
                        )
                      : null,
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              user.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 24,
              ),
            ),

            const SizedBox(height: 6),

            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showChangeRoleDialog(context, auth, user.role),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: user.isDualRole
                      ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
                      : (user.isWorker
                          ? const Color(0xFF43E97B).withValues(alpha: 0.1)
                          : const Color(0xFFFF6584).withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: user.isDualRole
                        ? const Color(0xFF6C63FF).withValues(alpha: 0.4)
                        : (user.isWorker
                            ? const Color(0xFF43E97B).withValues(alpha: 0.3)
                            : const Color(0xFFFF6584).withValues(alpha: 0.3)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      user.isDualRole
                          ? Icons.all_inclusive_rounded
                          : (user.isWorker ? Icons.work_outline : Icons.post_add),
                      size: 14,
                      color: user.isDualRole
                          ? const Color(0xFF6C63FF)
                          : (user.isWorker
                              ? const Color(0xFF43E97B)
                              : const Color(0xFFFF6584)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user.roleDisplayName,
                      style: TextStyle(
                        color: user.isDualRole
                            ? const Color(0xFF6C63FF)
                            : (user.isWorker
                                ? const Color(0xFF43E97B)
                                : const Color(0xFFFF6584)),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 12, color: Color(0xFF6A6A8A)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            Text(
              user.email,
              style: const TextStyle(color: Color(0xFF6A6A8A), fontSize: 13),
            ),

            const SizedBox(height: 24),

            // ── Rating ────────────────────────────────────────────────────
            GlassCard(
              child: Column(
                children: [
                  const Text(
                    'Worker Rating',
                    style: TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RatingBarIndicator(
                    rating: user.ratingAverage,
                    itemBuilder: (context, _) => const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFD700),
                    ),
                    itemCount: 5,
                    itemSize: 30,
                    unratedColor: const Color(0xFF2D2D4E),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        user.ratingAverage.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '/ 5.0 (${user.ratingCount} ratings)',
                        style: const TextStyle(
                          color: Color(0xFF6A6A8A),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Stats ──────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    value: user.tasksPosted.toString(),
                    label: 'Tasks\nPosted',
                    icon: Icons.post_add_rounded,
                    color: const Color(0xFF6C63FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    value: user.tasksCompleted.toString(),
                    label: 'Tasks\nDone',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF43E97B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    value: user.ratingAverage.toStringAsFixed(1),
                    label: 'Avg\nRating',
                    icon: Icons.star_outline,
                    color: const Color(0xFFFFD700),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Account info ───────────────────────────────────────────────
            GlassCard(
              child: Column(
                children: [
                  _InfoTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: user.email,
                  ),
                  const Divider(color: Color(0xFF2D2D4E), height: 20),
                  _InfoTile(
                    icon: Icons.badge_outlined,
                    label: 'User ID',
                    value: '${user.uid.substring(0, 12)}...',
                  ),
                  const Divider(color: Color(0xFF2D2D4E), height: 20),
                  _InfoTile(
                    icon: Icons.category_outlined,
                    label: 'Account Role',
                    value: user.roleDisplayName,
                    trailing: TextButton(
                      onPressed: () => _showChangeRoleDialog(context, auth, user.role),
                      child: const Text('Change', style: TextStyle(color: Color(0xFF6C63FF), fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Sign out
            GradientButton(
              label: 'Sign Out',
              icon: Icons.logout_rounded,
              gradient: const [Color(0xFFFF6584), Color(0xFFFF4757)],
              onPressed: () async {
                await auth.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
    ),
    );
  }

  void _showChangeRoleDialog(BuildContext context, AuthProvider auth, UserRole currentRole) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Choose Account Role',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF6A6A8A)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Select how you would like to use TaskMate:',
                style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildRoleOption(
                ctx: ctx,
                title: 'Both (Post & Do Tasks)',
                subtitle: 'Full access to post gigs and earn by accepting tasks',
                icon: Icons.all_inclusive_rounded,
                color: const Color(0xFF6C63FF),
                selected: currentRole == UserRole.both,
                onTap: () async {
                  Navigator.pop(ctx);
                  await auth.updateRole(UserRole.both);
                },
              ),
              const SizedBox(height: 10),
              _buildRoleOption(
                ctx: ctx,
                title: 'Task Creator Only',
                subtitle: 'Primarily post tasks and hire local workers',
                icon: Icons.post_add_rounded,
                color: const Color(0xFFFF6584),
                selected: currentRole == UserRole.creator,
                onTap: () async {
                  Navigator.pop(ctx);
                  await auth.updateRole(UserRole.creator);
                },
              ),
              const SizedBox(height: 10),
              _buildRoleOption(
                ctx: ctx,
                title: 'Task Worker Only',
                subtitle: 'Accept tasks nearby and earn money',
                icon: Icons.work_outline_rounded,
                color: const Color(0xFF43E97B),
                selected: currentRole == UserRole.worker,
                onTap: () async {
                  Navigator.pop(ctx);
                  await auth.updateRole(UserRole.worker);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleOption({
    required BuildContext ctx,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : const Color(0xFF0F0F1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : const Color(0xFF2D2D4E),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF6A6A8A), fontSize: 11),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6A6A8A),
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6C63FF), size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF6A6A8A),
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
