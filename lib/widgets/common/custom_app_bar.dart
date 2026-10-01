import 'dart:ui';
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final Color? titleColor;
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.titleColor,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AppBar(
          backgroundColor: const Color(0xFF0F0F1A).withValues(alpha: 0.8),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          automaticallyImplyLeading: showBackButton,
          leading: leading ??
              (showBackButton
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacementNamed(context, '/home');
                        }
                      },
                      color: Colors.white,
                      tooltip: 'Back',
                    )
                  : null),
          title: Text(
            title,
            style: TextStyle(
              color: titleColor ?? Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: 0.3,
            ),
          ),
          actions: actions,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFF2D2D4E),
                  width: 0.5,
                ),
              ),
            ),
          ),
          bottom: bottom,
        ),
      ),
    );
  }
}

/// Gradient text logo for splash/auth screens
class TaskMateLogo extends StatelessWidget {
  final double fontSize;

  const TaskMateLogo({super.key, this.fontSize = 36});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Text(
        'TaskMate',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
