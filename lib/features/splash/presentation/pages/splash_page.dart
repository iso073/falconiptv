import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/falcon_logo.dart';
import '../../../profile/presentation/pages/profile_selection_page.dart';
import '../../../../core/device/app_layout.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const Duration _hold = Duration(milliseconds: 1600);

  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
    _timer = Timer(_hold, _openProfiles);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _openProfiles() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ProfileSelectionPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.ambientGlow),
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 600),
            opacity: _visible ? 1 : 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FalconLogo(height: AppLayout.splashLogo(context), glow: true),
                const SizedBox(height: 18),
                const Text(
                  'Sisteme Hoş Geldiniz',
                  style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 36),
                const SizedBox(
                  width: 220,
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    color: AppColors.neonCyan,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
