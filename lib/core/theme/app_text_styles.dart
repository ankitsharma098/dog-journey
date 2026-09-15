import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Nunito reads friendly and rounded, which matches the glass/pastel look
/// better than a geometric sans. Applied once here so no screen hardcodes
/// a font.
abstract final class AppTextStyles {
  static TextTheme textTheme(Brightness brightness) {
    final base = GoogleFonts.nunitoTextTheme();
    final color = brightness == Brightness.dark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    return base
        .apply(bodyColor: color, displayColor: color)
        .copyWith(
          headlineLarge: base.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          bodyLarge: base.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        );
  }
}
