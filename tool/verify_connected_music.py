"""Run connected-account regressions and optionally capture the account screen."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import urllib.request

root = Path(__file__).resolve().parents[1]
flutter = Path(shutil.which("flutter") or "C:/flutter/bin/flutter.bat").parent.parent
dart = flutter / "bin/cache/dart-sdk/bin/dart.exe"
snapshot = flutter / "bin/cache/flutter_tools.snapshot"
environment = os.environ.copy()
environment["CAPTURE_CONNECTED_UI"] = "1"
font_directory = root / "build/connected_fonts"
font_directory.mkdir(parents=True, exist_ok=True)
for family, filename in {"outfit": "Outfit%5Bwght%5D.ttf", "inter": "Inter%5Bopsz,wght%5D.ttf"}.items():
    destination = font_directory / f"{family}.ttf"
    if not destination.exists():
        urllib.request.urlretrieve(f"https://raw.githubusercontent.com/google/fonts/main/ofl/{family}/{filename}", destination)
environment["CONNECTED_FONT_DIR"] = str(font_directory)
environment["FLUTTER_MATERIAL_FONTS"] = str(flutter / "bin/cache/artifacts/material_fonts")
commands = [
    ["node", "--test", "test/account_addons/account_readers_test.cjs"],
    [str(dart), str(snapshot), "test", "--no-pub",
     "test/unit/services/connected_music_service_test.dart",
     "test/unit/widgets/connected_music_widgets_test.dart",
     "test/unit/widgets/new_discovery_responsive_test.dart",
     "test/unit/services/discovery_and_mix_test.dart",
     "test/unit/services/collection_download_queue_test.dart",
     "test/unit/services/audio_source_policy_test.dart",
     "test/unit/services/connected_audio_recovery_test.dart",
     "test/unit/services/connected_playlist_file_cache_test.dart",
     "test/unit/widgets/discovery_mix_ui_test.dart"],
]
for command in commands:
    result = subprocess.run(command, cwd=root, env=environment)
    if result.returncode:
        sys.exit(result.returncode)
