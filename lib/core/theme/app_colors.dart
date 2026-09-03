import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color background = Color(0xFF0A0B10);
  static const Color surface = Color(0xFF12141C);
  static const Color surfaceElevated = Color(0xFF181B26);
  static const Color neonCyan = Color(0xFF00F0FF);
  static const Color neonPurple = Color(0xFFB026FF);
  static const Color textPrimary = Color(0xFFF4F7FF);
  static const Color textSecondary = Color(0xFFA8B0C4);
  static const Color danger = Color(0xFFFF4D6D);
  static const Color success = Color(0xFF3DFF9A);
  static const Color glass = Color(0x14FFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);

  static LinearGradient get ambientGlow => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0A0B10),
          Color(0xFF101325),
          Color(0xFF0A0B10),
        ],
      );
}
