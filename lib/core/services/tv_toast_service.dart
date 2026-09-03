import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum TvToastType { error, warning, success, info }

abstract final class TvToastService {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    TvToastType type = TvToastType.error,
    Duration duration = const Duration(seconds: 3),
  }) {
    hide();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    final Color accent = switch (type) {
      TvToastType.error => AppColors.danger,
      TvToastType.warning => const Color(0xFFFFC857),
      TvToastType.success => AppColors.success,
      TvToastType.info => AppColors.neonCyan,
    };

    _entry = OverlayEntry(
      builder: (context) {
        return IgnorePointer(
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48, left: 48, right: 48),
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: accent, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.45),
                            blurRadius: 28,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 22,
                        ),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 26,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(
                                color: accent.withValues(alpha: 0.55),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_entry!);
    _timer = Timer(duration, hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}
