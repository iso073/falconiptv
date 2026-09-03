import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FalconLogo extends StatelessWidget {
  const FalconLogo({
    super.key,
    this.height = 48,
    this.glow = false,
  });

  static const String assetPath = 'assets/branding/falcon_logo.png';

  final double height;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final Widget mark = Image.asset(
      assetPath,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.play_circle_outline_rounded,
        size: height * 0.72,
        color: AppColors.neonCyan,
      ),
    );

    if (!glow) {
      return mark;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.neonCyan.withValues(alpha: 0.28),
            blurRadius: height * 0.45,
            spreadRadius: 1,
          ),
        ],
      ),
      child: mark,
    );
  }
}
