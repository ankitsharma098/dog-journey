import 'package:flutter/material.dart';

/// "Royal" / Nocturne palette — deep ink ground, blurple accent, and a
/// champagne hairline reserved for the passport, the crest and Pro
/// surfaces only (never flooded across large areas).
/// Source: design-ref/design_handoff_royal_redesign/README.md § Design Tokens.
abstract final class AppColors {
  // ---- Dark theme (primary) ----
  static const Color canvasDark = Color(0xFF161826);
  static const Color cardDark = Color(0xFF232532);
  /// Bottom-sheet background and the passport segmented-control track.
  static const Color sheetDark = Color(0xFF1D1F2C);

  static const Color textPrimaryDark = Color(0xFFE9E9ED);
  static const Color textSecondaryDark = Color(0x9EE9E9ED); // 62%
  static const Color textTertiaryDark = Color(0x73E9E9ED); // 45%
  static const Color hairlineDark = Color(0x14E9E9ED); // 8%
  static const Color dividerDark = Color(0x29E9E9ED); // 16%

  /// Accent (blurple) — primary interactive colour on dark surfaces.
  static const Color accent = Color(0xFF9184D9);
  /// Icons, links, active nav glyph.
  static const Color accentLight = Color(0xFFB5ABFC);
  /// On-tint text (e.g. inside a filled accent chip).
  static const Color accentLightest = Color(0xFFD2CEFD);
  /// Fills, gradients, the user's chat bubble; also the light-theme accent.
  static const Color accentDeep = Color(0xFF5D5294);

  /// Champagne (gold) — passport, crest and Pro surfaces only.
  static const Color champagne = Color(0xFFD8BD86);

  static const Color success = Color(0xFF5FC79A);
  static const Color warningDark = Color(0xFFE0A458);
  static const Color dangerDark = Color(0xFFE0736B);
  /// Contrast-corrected emergency text sitting on a danger tint.
  static const Color emergencyTextDark = Color(0xFFF5A49D);

  // ---- Light theme (parchment) ----
  static const Color canvasLight = Color(0xFFF3F2F7);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color sheetLight = Color(0xFFE9E7F0);

  static const Color textPrimaryLight = Color(0xFF1B1A24);
  static const Color textSecondaryLight = Color(0xFF6A6878);
  static const Color textTertiaryLight = Color(0xFF8B8998);
  static const Color hairlineLight = Color(0x141B1A24); // 8%
  static const Color dividerLight = Color(0x291B1A24); // 16%

  /// Deeper than the dark-theme accent, for contrast on white.
  static const Color accentOnLight = accentDeep;
  static const Color champagneLight = Color(0xFF8A6F34);
  static const Color warningLight = Color(0xFFA4661A);
  static const Color dangerLight = Color(0xFFB54A42);

  static const Color cardShadowLight = Color(0x0F1B1A24); // 6%
  static const Color navShadowLight = Color(0x1A1B1A24); // 10%

  // ---- Brightness-aware helpers (no bare-name legacy collision) ----
  static Color canvas(Brightness b) => b == Brightness.dark ? canvasDark : canvasLight;
  static Color card(Brightness b) => b == Brightness.dark ? cardDark : cardLight;
  static Color sheet(Brightness b) => b == Brightness.dark ? sheetDark : sheetLight;
  static Color textPrimary(Brightness b) => b == Brightness.dark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(Brightness b) => b == Brightness.dark ? textSecondaryDark : textSecondaryLight;
  static Color textTertiary(Brightness b) => b == Brightness.dark ? textTertiaryDark : textTertiaryLight;
  static Color hairline(Brightness b) => b == Brightness.dark ? hairlineDark : hairlineLight;
  static Color divider(Brightness b) => b == Brightness.dark ? dividerDark : dividerLight;
  static Color accentOn(Brightness b) => b == Brightness.dark ? accent : accentOnLight;
  static Color champagneOn(Brightness b) => b == Brightness.dark ? champagne : champagneLight;
  static Color warningOn(Brightness b) => b == Brightness.dark ? warningDark : warningLight;
  static Color dangerOn(Brightness b) => b == Brightness.dark ? dangerDark : dangerLight;

  // ---- Legacy bare names kept for screens not yet migrated to the
  // Royal system (see the PR-sized rollout in
  // design_handoff_royal_redesign/README.md). Point at the dark-theme
  // ("primary theme") values so unmigrated screens still read correctly
  // by default; each is replaced by the brightness-aware helpers above
  // as its screen is redone. ----
  static const Color primary = accent;
  static const Color primarySoft = Color(0x1F9184D9); // ~12% accent tint
  static const Color cardBorderDark = hairlineDark;
  static const Color cardBorderLight = hairlineLight;
  static const Color chipFillDark = Color(0x12E9E9ED); // 7%
  static const Color chipFillLight = sheetLight;
  static const Color iconTileDark = Color(0x299184D9); // 16% accent
  static const Color iconTileLight = Color(0x1F5D5294); // 12% accentDeep
  static const Color warning = warningDark;
  static const Color danger = dangerDark;
  static const Color emergency = Color(0xFFDC2626);
}
