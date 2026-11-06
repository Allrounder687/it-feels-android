import 'package:flutter/material.dart';
import '../theme/new_experience_tokens.dart';

class NewSectionHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final VoidCallback? onAction;
  final String actionLabel;
  final IconData? actionIcon;

  const NewSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.onAction,
    this.actionLabel = 'See All',
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: NewExperienceTokens.eyebrowLabel(),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  title,
                  style: NewExperienceTokens.sectionTitle(),
                ),
              ],
            ),
          ),
          if (onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: NewExperienceTokens.specularBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel,
                      style: NewExperienceTokens.captionMuted(
                        color: NewExperienceTokens.textSecondary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      actionIcon ?? Icons.chevron_right_rounded,
                      size: 14,
                      color: NewExperienceTokens.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
