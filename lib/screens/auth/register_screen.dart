import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/custom_app_bar.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _selectedRole = UserRole.both;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          _buildOrb(top: -60, left: -60, size: 260, color: const Color(0xFF43E97B), opacity: 0.1),
          _buildOrb(bottom: -80, right: -60, size: 300, color: const Color(0xFF6C63FF), opacity: 0.12),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),

                    const Center(child: TaskMateLogo(fontSize: 36)),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'Create your account',
                        style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Role selector — the "power" UX
                    const Text(
                      'I want to...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _RoleCard(
                      role: UserRole.both,
                      selected: _selectedRole == UserRole.both,
                      icon: Icons.all_inclusive_rounded,
                      title: 'Both (Post & Do Tasks)',
                      subtitle: 'Post gigs when you need help, earn money doing tasks',
                      color: const Color(0xFF6C63FF),
                      onTap: () => setState(() => _selectedRole = UserRole.both),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _RoleCard(
                            role: UserRole.creator,
                            selected: _selectedRole == UserRole.creator,
                            icon: Icons.post_add_rounded,
                            title: 'Post Tasks Only',
                            subtitle: 'Hire local workers',
                            color: const Color(0xFFFF6584),
                            onTap: () => setState(() => _selectedRole = UserRole.creator),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _RoleCard(
                            role: UserRole.worker,
                            selected: _selectedRole == UserRole.worker,
                            icon: Icons.work_outline_rounded,
                            title: 'Find Work Only',
                            subtitle: 'Accept gigs & earn',
                            color: const Color(0xFF43E97B),
                            onTap: () => setState(() => _selectedRole = UserRole.worker),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Form card
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Full Name'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _nameController,
                              hint: 'John Doe',
                              icon: Icons.person_outline,
                              validator: (v) => (v == null || v.trim().length < 2)
                                  ? 'Please enter your full name'
                                  : null,
                            ),

                            const SizedBox(height: 18),

                            _buildLabel('Email Address'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _emailController,
                              hint: 'you@example.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Please enter your email';
                                if (!v.contains('@')) return 'Invalid email address';
                                return null;
                              },
                            ),

                            const SizedBox(height: 18),

                            _buildLabel('Password'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _passwordController,
                              hint: 'Min. 6 characters',
                              icon: Icons.lock_outline,
                              obscure: _obscurePassword,
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'Minimum 6 characters required'
                                  : null,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF4A4A6A),
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Error
                            Consumer<AuthProvider>(
                              builder: (_, auth, __) {
                                if (auth.errorMessage != null) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6584).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFFF6584).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        auth.errorMessage!,
                                        style: const TextStyle(
                                          color: Color(0xFFFF6584),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),

                            Consumer<AuthProvider>(
                              builder: (_, auth, __) => GradientButton(
                                label: 'Create Account',
                                isLoading: auth.isLoading,
                                icon: Icons.arrow_forward_rounded,
                                gradient: _selectedRole == UserRole.worker
                                    ? const [Color(0xFF43E97B), Color(0xFF38F9D7)]
                                    : const [Color(0xFF6C63FF), Color(0xFF9C5FC8)],
                                onPressed: () => _register(auth),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Already have an account? ',
                            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushReplacementNamed(context, '/login'),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                color: Color(0xFF6C63FF),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _register(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    final success = await auth.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole,
    );
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF9E9E9E),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF3A3A5A)),
        prefixIcon: Icon(icon, color: const Color(0xFF4A4A6A), size: 20),
        suffixIcon: suffix,
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
      ),
    );
  }

  Widget _buildOrb({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required Color color,
    required double opacity,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? color : const Color(0xFF2D2D4E),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? color.withValues(alpha: 0.2) : const Color(0xFF2D2D4E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: selected ? color : const Color(0xFF9E9E9E), size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF9E9E9E),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF6A6A8A),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
              if (selected)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(Icons.check_circle_rounded, color: color, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
