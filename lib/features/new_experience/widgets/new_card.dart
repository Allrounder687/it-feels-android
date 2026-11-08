import 'package:flutter/material.dart';
import '../theme/new_experience_tokens.dart';
import 'new_artwork_image.dart';

class NewCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? badgeText;
  final Widget? customArtwork;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final double width;
  final double aspectRatio;
  final IconData placeholderIcon;

  const NewCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.badgeText,
    this.customArtwork,
    required this.onTap,
    this.onPlay,
    this.width = 164.0,
    this.aspectRatio = 1.0,
    this.placeholderIcon = Icons.music_note_rounded,
  });

  @override
  State<NewCard> createState() => _NewCardState();
}

class _NewCardState extends State<NewCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cardHeight = widget.width / widget.aspectRatio;

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: widget.width,
            transform: Matrix4.identity()..translate(0.0, _isHovered ? -4.0 : 0.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Artwork container with hover elevation and play button
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: widget.aspectRatio,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(NewExperienceTokens.radiusMedium),
                          border: Border.all(
                            color: _isHovered
                                ? NewExperienceTokens.accentViolet.withValues(alpha: 0.5)
                                : NewExperienceTokens.specularBorder,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: _isHovered ? 0.45 : 0.25),
                              blurRadius: _isHovered ? 16 : 8,
                              offset: Offset(0, _isHovered ? 8 : 4),
                            ),
                          ],
                        ),
                        child: widget.customArtwork != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(NewExperienceTokens.radiusMedium),
                                child: widget.customArtwork!,
                              )
                            : NewArtworkImage(
                                imageUrl: widget.imageUrl,
                                width: widget.width,
                                height: cardHeight,
                                fit: BoxFit.cover,
                                borderRadius: BorderRadius.circular(NewExperienceTokens.radiusMedium),
                                iconSize: 32,
                                fallbackTitle: widget.title,
                              ),
                      ),
                    ),

                  // Optional Badge (e.g. "DAILY MIX", "TOP HIT")
                  if (widget.badgeText != null && widget.customArtwork == null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          widget.badgeText!,
                          style: NewExperienceTokens.eyebrowLabel(
                            color: NewExperienceTokens.accentCyan,
                          ).copyWith(fontSize: 9),
                        ),
                      ),
                    ),

                  // Play Button Hover Overlay
                  if (widget.onPlay != null)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _isHovered ? 1.0 : 0.0,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onPlay,
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: NewExperienceTokens.accentViolet,
                                boxShadow: [
                                  BoxShadow(
                                    color: NewExperienceTokens.accentViolet.withValues(alpha: 0.45),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NewExperienceTokens.bodyMedium(
                  color: _isHovered
                      ? NewExperienceTokens.accentViolet
                      : NewExperienceTokens.textPrimary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),

              // Subtitle
              if (widget.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  widget.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NewExperienceTokens.bodySmall(
                    color: NewExperienceTokens.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  }
}
