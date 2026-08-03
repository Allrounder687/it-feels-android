import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux)) {
      return const SizedBox.shrink();
    }
    
    return SizedBox(
      height: 32, // Equivalent to window_manager's kWindowCaptionHeight
      child: Container(
        color: Colors.black.withOpacity(0.5), // Semi-transparent blending
        child: const WindowCaption(
          brightness: Brightness.dark,
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}
