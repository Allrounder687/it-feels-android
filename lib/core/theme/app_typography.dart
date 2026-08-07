import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  // Pre-compiled TextStyles for Inter
  static final TextStyle interNormal = GoogleFonts.inter();
  static final TextStyle interMedium = GoogleFonts.inter(fontWeight: FontWeight.w500);
  static final TextStyle interSemiBold = GoogleFonts.inter(fontWeight: FontWeight.w600);
  static final TextStyle interBold = GoogleFonts.inter(fontWeight: FontWeight.w700);

  // Pre-compiled TextStyles for Outfit
  static final TextStyle outfitNormal = GoogleFonts.outfit();
  static final TextStyle outfitMedium = GoogleFonts.outfit(fontWeight: FontWeight.w500);
  static final TextStyle outfitSemiBold = GoogleFonts.outfit(fontWeight: FontWeight.w600);
  static final TextStyle outfitBold = GoogleFonts.outfit(fontWeight: FontWeight.w700);
  static final TextStyle outfitExtraBold = GoogleFonts.outfit(fontWeight: FontWeight.w800);

  // Pre-compiled global TextThemes
  static final TextTheme lightTextTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);
  static final TextTheme darkTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
}
