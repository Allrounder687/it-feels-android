import 'package:flutter/material.dart';
import '../theme/new_experience_tokens.dart';

enum NewActionButtonVariant {
  primary,
  glass,
  circularPlay,
}

class NewActionButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onPressed;
  final NewActionButtonVariant variant;
  final double? width;
  final double height;
  final Color? customAccent;

  const NewActionButton({
    super.key,
    this.label,
    this.icon,
    required this.onPressed,
    this.variant = NewActionButtonVariant.primary,
    this.width,
    this.height = 44.0,
    this.customAccent,
  });

  @override
  Widget build(BuildContext context) {
    final accent = customAccent ?? NewExperienceTokens.accentViolet;

    if (variant == NewActionButtonVariant.circularPlay) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(height / 2),
          child: Container(
            width: height,
            height: height,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon ?? Icons.play_arrow_rounded,
              color: Colors.white,
              size: height * 0.55,
            ),
          ),
        ),
      );
    }

    final isPrimary = variant == NewActionButtonVariant.primary;

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? accent : Colors.white.withValues(alpha: 0.08),
          foregroundColor: isPrimary ? Colors.white : NewExperienceTokens.textPrimary,
          elevation: isPrimary ? 4 : 0,
          shadowColor: isPrimary ? accent.withValues(alpha: 0.35) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NewExperienceTokens.radiusPill),
            side: isPrimary
                ? BorderSide.none
                : BorderSide(color: NewExperienceTokens.specularBorder, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              if (label != null) const SizedBox(width: 8),
            ],
            if (label != null)
              Text(
                label!,
                style: NewExperienceTokens.bodyMedium(
                  color: isPrimary ? Colors.white : NewExperienceTokens.textPrimary,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }
}
