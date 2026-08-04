import os
import re

file_path = 'lib/features/settings/storage_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Import the new provider
if 'storage_provider.dart' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:it_feels_music/features/settings/storage_provider.dart';")

# Change to ConsumerWidget
content = re.sub(r'class StorageScreen extends ConsumerStatefulWidget \{[\s\S]*?class _StorageScreenState extends ConsumerState<StorageScreen> \{', 'class StorageScreen extends ConsumerWidget {', content)

# Remove locator and state vars
content = re.sub(r'final SmartStorageService _storageService = locator<SmartStorageService>\(\);\s*bool _isLoading.*?\n  bool _autoDownload = false;\s*@override\s*void initState\(\) \{.*?\n  \}\s*Future<void> _loadStorageData\(\) async \{.*?\n  \}', '', content, flags=re.DOTALL)

# Add build method with ref
content = content.replace('@override\n  Widget build(BuildContext context) {', '@override\n  Widget build(BuildContext context, WidgetRef ref) {\n    final state = ref.watch(storageProvider);\n    final notifier = ref.read(storageProvider.notifier);')

# Replace direct references
content = content.replace('_isLoading', 'state.isLoading')
content = content.replace('_cacheSize', 'state.cacheSize')
content = content.replace('_downloadSize', 'state.downloadSize')
content = content.replace('_maxCacheSize', 'state.maxCacheSize')
content = content.replace('_autoDownload', 'state.autoDownload')

content = content.replace('_loadStorageData', 'notifier.loadStorageData')

# Change onPressed logic
content = re.sub(r'onPressed:\s*\(\)\s*async\s*\{\s*setState\(\(\)\s*=>\s*state\.isLoading\s*=\s*true\);\s*await\s*_storageService\.clearCache\(\);\s*await\s*notifier\.loadStorageData\(\);\s*\}', 'onPressed: () => notifier.clearCache()', content)
content = re.sub(r'onPressed:\s*\(\)\s*async\s*\{\s*setState\(\(\)\s*=>\s*state\.isLoading\s*=\s*true\);\s*await\s*_storageService\.clearDownloads\(\);\s*await\s*notifier\.loadStorageData\(\);\s*\}', 'onPressed: () => notifier.clearDownloads()', content)
content = re.sub(r'onChanged:\s*\(val\)\s*async\s*\{\s*await\s*_storageService\.setAutoDownloadFavorites\(val\);\s*setState\(\(\)\s*=>\s*state\.autoDownload\s*=\s*val\);\s*\}', 'onChanged: (val) => notifier.toggleAutoDownload(val)', content)

# Remove unused imports if any
content = content.replace("import 'package:it_feels_music/core/utils/service_locator.dart';", "")
content = content.replace("import 'package:it_feels_music/data/services/smart_storage_service.dart';", "")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
