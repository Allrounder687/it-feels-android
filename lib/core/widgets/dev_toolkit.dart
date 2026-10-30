import 'package:flutter/material.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/core/router/app_router.dart';
import 'package:it_feels_music/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';

class DevToolkitOverlay extends StatefulWidget {
  const DevToolkitOverlay({super.key});

  @override
  State<DevToolkitOverlay> createState() => _DevToolkitOverlayState();
}

class _DevToolkitOverlayState extends State<DevToolkitOverlay> {
  bool _isOpen = false;
  double _right = 16.0;
  double _top = 220.0;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      right: _right,
      top: _top,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _right = (_right - details.delta.dx).clamp(0.0, screenSize.width - 60.0);
            _top = (_top + details.delta.dy).clamp(60.0, screenSize.height - 120.0);
          });
        },
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isOpen ? Colors.black87 : Colors.deepPurpleAccent.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(_isOpen ? 16 : 30),
              border: Border.all(color: Colors.white24),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_isOpen ? Icons.close : Icons.bug_report, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isOpen = !_isOpen;
                        });
                      },
                    ),
                    if (_isOpen)
                      const Padding(
                        padding: EdgeInsets.only(right: 16.0),
                        child: Text(
                          "DEV TOOLS",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_isOpen)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildToolButton(
                          icon: Icons.restart_alt,
                          label: "Reset Onboarding",
                          onTap: () async {
                            await StorageService.setHasSeenOnboarding(false);
                            rootScaffoldMessengerKey.currentState?.showSnackBar(
                              const SnackBar(content: Text('Onboarding cache cleared! Hot Restart app or use "Go to Onboarding"')),
                            );
                          },
                        ),
                        _buildToolButton(
                          icon: Icons.rocket_launch,
                          label: "Force Go to Onboarding",
                          onTap: () {
                            appRouter.go('/onboarding');
                          },
                        ),
                        Consumer(
                          builder: (context, ref, _) {
                            final uiMode = ref.watch(settingsProvider).uiExperienceMode;
                            final isNeo = uiMode == UiExperienceMode.appleNeo;
                            return _buildToolButton(
                              icon: isNeo ? Icons.phone_iphone_rounded : Icons.dashboard_customize_rounded,
                              label: 'UI: ${isNeo ? "Apple Neo" : "Classic"}',
                              onTap: () {
                                final next = isNeo ? UiExperienceMode.classic : UiExperienceMode.appleNeo;
                                ref.read(settingsProvider.notifier).setUiExperienceMode(next);
                                rootScaffoldMessengerKey.currentState?.showSnackBar(
                                  SnackBar(content: Text('Switched UI Mode to ${next == UiExperienceMode.appleNeo ? "Apple Neo" : "Classic"}')),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
