import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/royal/crest.dart';
import '../widgets/royal/fading_rule.dart';

/// Shown for the moment between app start and the first Supabase Auth
/// event — the router redirects away from here the instant AuthBloc
/// leaves [AuthInitial]. A hold, not a timed intro — no progress bar,
/// no tagline, nothing that implies waiting. See README § "0a. Splash".
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final champagne = AppColors.champagneOn(Brightness.dark);
    return Scaffold(
      backgroundColor: AppColors.canvasDark,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.16),
            radius: 0.9,
            colors: [Color(0xFF2B2741), AppColors.canvasDark],
            stops: [0, 0.7],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RoyalCrest(size: 104, borderAlpha: 0.6),
              const SizedBox(height: 22),
              Text(
                'PAWJOURNEY',
                style: AppTextStyles.engravedLabel.copyWith(
                  fontSize: 11,
                  letterSpacing: 0.44 * 11,
                  color: champagne,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(width: 96, child: FadingRule(color: champagne)),
            ],
          ),
        ),
      ),
    );
  }
}
