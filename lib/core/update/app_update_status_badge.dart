import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../theme/app_colors.dart';
import '../widgets/neon_focus_card.dart';
import 'app_update_flow.dart';
import 'app_update_service.dart';
import 'update_status_cubit.dart';

class AppUpdateStatusBadge extends StatelessWidget {
  const AppUpdateStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UpdateStatusCubit, UpdateStatusState>(
      builder: (context, state) {
        final Color color = switch (state.phase) {
          UpdateStatusPhase.current => AppColors.success,
          UpdateStatusPhase.available => AppColors.neonCyan,
          UpdateStatusPhase.checking => AppColors.textSecondary,
          UpdateStatusPhase.failed => AppColors.danger,
        };
        return NeonFocusCard(
          focusedScale: 1.04,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          glowColor: color,
          onActivate: () => _onActivate(context, state),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                switch (state.phase) {
                  UpdateStatusPhase.current => Icons.verified_rounded,
                  UpdateStatusPhase.available => Icons.system_update_alt_rounded,
                  UpdateStatusPhase.checking => Icons.sync_rounded,
                  UpdateStatusPhase.failed => Icons.error_outline_rounded,
                },
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                state.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onActivate(BuildContext context, UpdateStatusState state) async {
    final UpdateStatusCubit cubit = context.read<UpdateStatusCubit>();
    final AppUpdateService service = context.read<AppUpdateService>();
    if (state.phase == UpdateStatusPhase.available) {
      await AppUpdateFlow.check(context, service, force: true);
      if (context.mounted) {
        await cubit.refresh();
      }
      return;
    }
    await cubit.refresh();
  }
}
