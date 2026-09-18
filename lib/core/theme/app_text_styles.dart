import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Inter throughout — the Royal redesign standardises on one typeface
/// (dropping the previous Nunito/Sora mix). Named roles below mirror
/// the type-scale table in
/// design-ref/design_handoff_royal_redesign/README.md; screens should
/// reach for these rather than hand-rolling a `TextStyle`.
abstract final class AppTextStyles {
  /// Base [TextTheme] for Material widgets and screens not yet
  /// migrated to the named roles below.
  static TextTheme textTheme(Brightness brightness) {
    final color = AppColors.textPrimary(brightness);
    // Apply the theme's colour FIRST, then override weights on the
    // now-coloured styles — copyWith-ing from the pre-apply `base`
    // instead would silently drop the colour back to GoogleFonts'
    // default (near-black), which is invisible on a dark canvas. This
    // is what made typed text in every AppTextField (sign in/up, add
    // pet) unreadable in dark mode.
    final applied = GoogleFonts.interTextTheme().apply(
      bodyColor: color,
      displayColor: color,
    );

    return applied.copyWith(
      headlineLarge: applied.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: applied.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: applied.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: applied.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: applied.bodyLarge?.copyWith(fontWeight: FontWeight.w400),
      labelLarge: applied.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  /// Home H1 / Story / Settings screen title. 24 / 700 / −0.02em.
  static TextStyle screenTitle = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02 * 24,
    height: 1.2,
  );

  /// Passport / Nutrition screen title. 21 / 700 / −0.02em.
  static TextStyle screenTitleCompact = GoogleFonts.inter(
    fontSize: 21,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02 * 21,
    height: 1.2,
  );

  /// Bottom-sheet title. 20 / 700 / −0.02em.
  static TextStyle sheetTitle = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02 * 20,
  );

  /// Onboarding H1. 30 / 600 / −0.02em, line-height 1.18.
  static TextStyle onboardingHeadline = GoogleFonts.inter(
    fontSize: 30,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.02 * 30,
    height: 1.18,
  );

  /// Section heading ("Needs you this week", "Quick add"). 15 / 600.
  static TextStyle sectionHeading = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.01 * 15,
  );

  /// List-row title. 13.5 / 600.
  static TextStyle listRowTitle = GoogleFonts.inter(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
  );

  /// Body copy. 13 / 400 / line-height 1.6.
  static TextStyle body = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  /// Secondary line under a list-row title. 11.5 / 400.
  static TextStyle secondaryLine = GoogleFonts.inter(
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
  );

  /// Meta / caption text. 11 / 400.
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
  );

  /// Engraved kicker label ("HEALTH PASSPORT", "TODAY"). 9 / 600 /
  /// 0.30em / uppercase. Colour is champagne at the call site.
  static TextStyle engravedLabel = GoogleFonts.inter(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.30 * 9,
  );

  /// Chip / status-pill label. 10 / 600 / ~0.10em / uppercase.
  static TextStyle chipLabel = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.10 * 10,
  );

  /// Mono — passport number, timeline dates. 10 / 500 / 0.12em.
  static TextStyle mono = const TextStyle(
    fontFamily: 'monospace',
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.12 * 10,
  );
}
