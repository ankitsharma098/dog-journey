import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/glass/glass_scaffold.dart';

/// Shown for the moment between app start and the first Supabase Auth
/// event — the router redirects away from here the instant AuthBloc
/// leaves [AuthInitial], so this never needs its own navigation.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.pets_rounded, color: AppColors.primary, size: 36),
        ),
      ),
    );
  }
}
