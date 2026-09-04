import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../cubit/sport_mode_cubit.dart';

class SportModeStatusBadge extends StatelessWidget {
  const SportModeStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SportModeCubit, bool>(
      builder: (context, enabled) {
        if (!enabled) {
          return const SizedBox.shrink();
        }
        return const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Text(
            'Spor modu açık',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.neonCyan,
            ),
          ),
        );
      },
    );
  }
}
