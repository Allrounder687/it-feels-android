import 'package:flutter/material.dart';
import 'package:it_feels_music/services/playlist_import_service.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';

class ImportProgressBanner extends StatelessWidget {
  const ImportProgressBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlaylistImportProgress?>(
      valueListenable: PlaylistImportService().importProgress,
      builder: (context, progress, child) {
        if (progress == null) return const SizedBox.shrink();

        final double percent = progress.total == 0 
            ? 0.0 
            : progress.current / progress.total;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: context.themeInvertedTextColor.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    progress.isDone ? Icons.check_circle : Icons.cloud_sync,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      progress.status,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  if (!progress.isDone)
                    Text(
                      '${progress.current}/${progress.total}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
              if (!progress.isDone && progress.total > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    backgroundColor: Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
  }
}
