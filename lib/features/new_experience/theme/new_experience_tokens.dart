import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the 2026 New Experience presentation layer.
class NewExperienceTokens {
  // ── Surface & Canvas Colors ──
  static const Color obsidianBackground = Color(0xFF08080A);
  static const Color midnightSurface = Color(0xFF121217);
  static const Color elevatedGlass = Color(0xFF1A1A22);
  static const Color cardSurface = Color(0xFF16161D);

  // ── Specular & Border Accents ──
  static final Color specularBorder = Colors.white.withValues(alpha: 0.08);
  static final Color subtleDivider = Colors.white.withValues(alpha: 0.06);

  // ── Brand Accent Palette ──
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentRose = Color(0xFFF43F5E);
  static const Color accentAmber = Color(0xFFF59E0B);

  // ── Typography Contrast Levels ──
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // ── Geometry Radii ──
  static const double radiusSmall = 10.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 22.0;
  static const double radiusPill = 32.0;

  // ── Glass Refraction Blur ──
  static const double blurLight = 12.0;
  static const double blurStandard = 20.0;
  static const double blurIntense = 32.0;

  // ── Responsive Layout Breakpoints ──
  static const double breakpointCompact = 600.0; // Mobile Portrait
  static const double breakpointMedium = 1024.0; // Tablet / Mobile Landscape
  static const double breakpointDesktop = 1440.0; // Desktop

  // ── Typography Helpers ──
  static TextStyle displayHero({Color color = textPrimary, double? fontSize}) => GoogleFonts.outfit(
        fontSize: fontSize ?? 32,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.8,
        height: 1.15,
      );

  static TextStyle sectionTitle({Color color = textPrimary, double? fontSize}) => GoogleFonts.outfit(
        fontSize: fontSize ?? 20,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.4,
      );

  static TextStyle eyebrowLabel({Color color = accentCyan}) => GoogleFonts.inter(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 1.2,
      );

  static TextStyle bodyMedium({Color color = textPrimary}) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.35,
      );

  static TextStyle bodySmall({Color color = textSecondary}) => GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle captionMuted({Color color = textMuted}) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle numericTimer({Color color = textSecondary}) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
