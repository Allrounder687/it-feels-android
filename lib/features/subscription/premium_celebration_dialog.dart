import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:it_feels_music/core/theme/app_colors.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class PremiumCelebrationDialog extends StatefulWidget {
  final bool isFamilyCoupon;

  const PremiumCelebrationDialog({super.key, required this.isFamilyCoupon});

  static void show(BuildContext context, {required bool isFamilyCoupon}) {
    final settings = ProviderScope.containerOf(context).read(settingsProvider);

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return PremiumCelebrationDialog(isFamilyCoupon: isFamilyCoupon);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scaleFade = ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );

        if (settings.isPerformanceMode) {
          return scaleFade;
        }

        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 20 * animation.value,
            sigmaY: 20 * animation.value,
          ),
          child: scaleFade,
        );
      },
    );
  }

  @override
  State<PremiumCelebrationDialog> createState() => _PremiumCelebrationDialogState();
}

class _PremiumCelebrationDialogState extends State<PremiumCelebrationDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _rotationAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _confettiController.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.midnightSurface,
                AppColors.midnightPrimary.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.midnightAccent.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.midnightAccent.withValues(alpha: 0.3),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.midnightAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: AppColors.midnightAccent,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Welcome to Premium!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 24),
              if (widget.isFamilyCoupon)
                const Text(
                  "This is a special lifetime Family access pass.\n\nI worked incredibly hard to build this app from the ground up, pouring my heart and soul into every pixel and line of code.\n\nI hope you enjoy listening to your favorite music on it as much as I enjoyed creating it!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.white70,
                  ),
                )
              else
                const Text(
                  "Your subscription is now active! Enjoy Lossless Audio, unlimited Listen Together rooms, and an ad-free experience.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.white70,
                  ),
                ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midnightAccent,
                  foregroundColor: Colors.black,
                  elevation: 10,
                  shadowColor: AppColors.midnightAccent.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  "Let's Go",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    Align(
      alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: 3.14 / 2, // downwards
            blastDirectionality: BlastDirectionality.explosive,
            maxBlastForce: 20,
            minBlastForce: 8,
            emissionFrequency: 0.05,
            numberOfParticles: 50,
            gravity: 0.1,
            colors: const [
              Colors.amber,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple
            ],
          ),
        ),
      ],
    );
  }
}
