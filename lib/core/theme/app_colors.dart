import 'package:flutter/material.dart';

/// Premium modern palette: elegant indigo primary, clean canvas backgrounds,
/// and soft contrasting surfaces for a rich look.
abstract final class AppColors {
  // Brand (Premium Indigo)
  static const Color primary = Color(0xFF6366F1); // vibrant indigo
  static const Color primarySoft = Color(0xFFE0E7FF); // light indigo tint
  
  // Secondary / Accent (Teal for subtle pops)
  static const Color accent = Color(0xFF14B8A6);

  // Canvas (Clean and rich)
  static const Color canvasLight = Color(0xFFF8FAFC); // Slate 50
  static const Color canvasDark = Color(0xFF0F172A); // Slate 900

  // Background blobs (very low opacity, purely decorative)
  static const Color blobCool = Color(0xFF818CF8); // Indigo 400
  static const Color blobWarm = Color(0xFF2DD4BF); // Teal 400

  // Cards (Slightly elevated from canvas)
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1E293B); // Slate 800
  static const Color cardBorderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color cardBorderDark = Color(0xFF334155); // Slate 700

  // Chips / soft fills
  static const Color chipFillLight = Color(0xFFF1F5F9); // Slate 100
  static const Color chipFillDark = Color(0xFF334155); // Slate 700
  static const Color iconTileLight = Color(0xFFEEF2F6);
  static const Color iconTileDark = Color(0xFF1E293B);

  static const Color dividerLight = Color(0xFFE2E8F0);
  static const Color dividerDark = Color(0xFF334155);

  // Semantic
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color danger = Color(0xFFEF4444); // Red 500

  /// Reserved for the Module 3 emergency card only
  static const Color emergency = Color(0xFFDC2626); // Red 600

  // Typography
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate 500
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
}
