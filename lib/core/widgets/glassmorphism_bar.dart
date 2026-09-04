import 'dart:ui';

import 'package:flutter/material.dart';

import '../device/app_layout.dart';
import '../theme/app_colors.dart';

class GlassmorphismBar extends StatelessWidget {
  const GlassmorphismBar({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonCyan.withValues(alpha: 0.08),
                blurRadius: 24,
              ),
            ],
          ),
          child: Padding(
            padding: padding ?? AppLayout.glassPadding(context),
            child: child,
          ),
        ),
      ),
    );
  }
}
