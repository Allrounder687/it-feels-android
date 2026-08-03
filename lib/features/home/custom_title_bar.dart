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
    
    return DragToMoveArea(
      child: Container(
        height: 36,
        color: const Color(0xFF181B22),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'IT-Feels',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            IconButton(
              tooltip: 'Minimize',
              onPressed: windowManager.minimize,
              icon: const Icon(Icons.remove, color: Colors.white, size: 18),
            ),
            IconButton(
              tooltip: 'Maximize',
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              icon: const Icon(Icons.crop_square, color: Colors.white, size: 18),
            ),
            IconButton(
              tooltip: 'Close',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFC42B1C),
                shape: const RoundedRectangleBorder(),
              ),
              onPressed: windowManager.close,
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
