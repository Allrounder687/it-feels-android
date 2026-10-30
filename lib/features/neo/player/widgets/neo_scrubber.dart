import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class NeoScrubber extends ConsumerStatefulWidget {
  final Color accentColor;

  const NeoScrubber({
    super.key,
    required this.accentColor,
  });

  @override
  ConsumerState<NeoScrubber> createState() => _NeoScrubberState();
}

class _NeoScrubberState extends ConsumerState<NeoScrubber> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerProvider);
    final totalDuration = playerState.duration;
    final totalMs = totalDuration.inMilliseconds.toDouble();

    return StreamBuilder<Duration>(
      stream: ref.read(audioPlayerProvider.notifier).audioHandler.player.stream.position,
      initialData: playerState.position,
      builder: (context, snapshot) {
        final currentPos = snapshot.data ?? playerState.position;
        final currentMs = currentPos.inMilliseconds.toDouble();
        final progress = (totalMs > 0)
            ? (_isDragging ? _dragValue : (currentMs / totalMs)).clamp(0.0, 1.0)
            : 0.0;

        final displayCurrent = _isDragging
            ? Duration(milliseconds: (_dragValue * totalMs).round())
            : currentPos;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Interactive Slider with custom gesture detector for smooth expansion
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) {
                setState(() {
                  _isDragging = true;
                });
                HapticFeedback.selectionClick();
              },
              onHorizontalDragUpdate: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null || box.size.width <= 0) return;
                final localX = details.localPosition.dx;
                final newFraction = (localX / box.size.width).clamp(0.0, 1.0);
                setState(() {
                  _dragValue = newFraction;
                });
              },
              onHorizontalDragEnd: (details) {
                if (totalMs > 0) {
                  final targetMs = (_dragValue * totalMs).round();
                  ref.read(audioPlayerProvider.notifier).seek(
                        Duration(milliseconds: targetMs),
                      );
                }
                setState(() {
                  _isDragging = false;
                });
                HapticFeedback.lightImpact();
              },
              onTapDown: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null || box.size.width <= 0) return;
                final localX = details.localPosition.dx;
                final newFraction = (localX / box.size.width).clamp(0.0, 1.0);
                final targetMs = (newFraction * totalMs).round();
                ref.read(audioPlayerProvider.notifier).seek(
                      Duration(milliseconds: targetMs),
                    );
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: _isDragging ? 24 : 16,
                alignment: Alignment.center,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth = constraints.maxWidth;
                    final activeWidth = barWidth * progress;

                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Inactive track
                        Container(
                          height: _isDragging ? 7.0 : 4.0,
                          width: barWidth,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),

                        // Active track
                        Container(
                          height: _isDragging ? 7.0 : 4.0,
                          width: activeWidth,
                          decoration: BoxDecoration(
                            color: widget.accentColor,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: widget.accentColor.withValues(alpha: 0.45),
                                blurRadius: _isDragging ? 8 : 4,
                              ),
                            ],
                          ),
                        ),

                        // Thumb pill indicator when dragging
                        if (_isDragging)
                          Positioned(
                            left: (activeWidth - 6).clamp(0.0, barWidth - 12),
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Tabular Monospaced Timestamps
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(displayCurrent),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.65),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    _formatDuration(totalDuration),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.65),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
