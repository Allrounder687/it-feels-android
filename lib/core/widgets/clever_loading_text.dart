import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CleverLoadingText extends StatefulWidget {
  const CleverLoadingText({super.key});

  @override
  State<CleverLoadingText> createState() => _CleverLoadingTextState();
}

class _CleverLoadingTextState extends State<CleverLoadingText> {
  final List<String> _phrases = [
    "Warming up the stage...",
    "Bribing the YouTube algorithm...",
    "Tuning the virtual guitars...",
    "Finding the perfect pixels...",
    "Mic check, 1.. 2.. 3..",
    "Downloading more RAM...",
    "Reticulating audio splines...",
    "Convincing the servers to hurry up...",
    "Polishing the video stream...",
    "Syncing the lip movements...",
  ];

  late String _currentPhrase;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentPhrase = _phrases[Random().nextInt(_phrases.length)];
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      final newPhrase = _phrases[Random().nextInt(_phrases.length)];
      if (newPhrase != _currentPhrase) {
        setState(() {
          _currentPhrase = newPhrase;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.2),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Text(
          _currentPhrase,
          key: ValueKey<String>(_currentPhrase),
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
