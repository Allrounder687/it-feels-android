import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/widgets/tv_focusable_card.dart';

class GlassmorphicChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const GlassmorphicChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<GlassmorphicChip> createState() => _GlassmorphicChipState();
}

class _GlassmorphicChipState extends State<GlassmorphicChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: TVFocusableCard(
        onTap: widget.onTap,
        focusedScale: 1.1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.white
                : (_isHovered
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              color: widget.isSelected
                  ? Colors.black
                  : Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
