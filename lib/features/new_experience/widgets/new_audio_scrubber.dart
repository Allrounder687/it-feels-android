import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:it_feels_music/core/utils/string_utils.dart';
import '../theme/new_experience_tokens.dart';

/// Commercial-grade high-precision audio scrubber with drag debouncing,
/// haptic notches, and dynamic timestamp display.
class NewAudioScrubber extends StatefulWidget {
  final Duration currentPosition;
  final Duration totalDuration;
  final ValueChanged<Duration> onSeek;
  final Color activeColor;
  final Color inactiveColor;

  const NewAudioScrubber({
    super.key,
    required this.currentPosition,
    required this.totalDuration,
    required this.onSeek,
    this.activeColor = Colors.white,
    this.inactiveColor = const Color(0x33FFFFFF),
  });

  @override
  State<NewAudioScrubber> createState() => _NewAudioScrubberState();
}

class _NewAudioScrubberState extends State<NewAudioScrubber> {
  bool _isDragging = false;
  double _dragValueMs = 0.0;
  int _lastHapticMinute = -1;

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.totalDuration.inMilliseconds.toDouble();
    final maxMs = totalMs > 0.0 ? totalMs : 1.0;

    final displayPosMs = _isDragging
        ? _dragValueMs.clamp(0.0, maxMs)
        : widget.currentPosition.inMilliseconds.toDouble().clamp(0.0, maxMs);

    final displayPos = Duration(milliseconds: displayPosMs.toInt());
    final displayTotal = widget.totalDuration;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Smooth Slider with enlarged thumb on drag ──
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: _isDragging ? 5.5 : 4.0,
            trackShape: const RoundedRectSliderTrackShape(),
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: _isDragging ? 8.5 : 6.0,
              elevation: _isDragging ? 6.0 : 2.0,
              pressedElevation: 8.0,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            activeTrackColor: widget.activeColor,
            inactiveTrackColor: widget.inactiveColor,
            thumbColor: widget.activeColor,
            overlayColor: widget.activeColor.withValues(alpha: 0.18),
          ),
          child: Slider(
            value: displayPosMs,
            min: 0.0,
            max: maxMs,
            onChangeStart: (val) {
              setState(() {
                _isDragging = true;
                _dragValueMs = val;
                _lastHapticMinute = (val / 60000).floor();
              });
              HapticFeedback.selectionClick();
            },
            onChanged: (val) {
              setState(() {
                _dragValueMs = val;
              });

              // Subtle haptic feedback when scrubbing across full minute marks
              final currentMinute = (val / 60000).floor();
              if (currentMinute != _lastHapticMinute) {
                _lastHapticMinute = currentMinute;
                HapticFeedback.lightImpact();
              }
            },
            onChangeEnd: (val) {
              final target = Duration(milliseconds: val.toInt());
              setState(() {
                _isDragging = false;
              });
              HapticFeedback.mediumImpact();
              widget.onSeek(target);
            },
          ),
        ),

        // ── Timestamps Row ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                StringUtils.formatDuration(displayPos),
                style: NewExperienceTokens.numericTimer(
                  color: _isDragging
                      ? NewExperienceTokens.accentCyan
                      : Colors.white.withValues(alpha: 0.8),
                ),
              ),
              if (_isDragging)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: Text(
                    'SEEKING',
                    style: NewExperienceTokens.eyebrowLabel(color: Colors.white).copyWith(fontSize: 9),
                  ),
                ),
              Text(
                StringUtils.formatDuration(displayTotal),
                style: NewExperienceTokens.numericTimer(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
