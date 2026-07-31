import os
import shutil
import re

# Base directory paths
base_dir = r"d:\Organized_Downloads\Projects\Kreo Projects\IT-Feels\lib"
test_dir = r"d:\Organized_Downloads\Projects\Kreo Projects\IT-Feels\test"
features_dir = os.path.join(base_dir, "features")

# Mapping of file basenames to their new feature domain
feature_map = {
    # Auth
    "auth_bottom_sheet.dart": "auth",
    "auth_provider.dart": "auth",
    
    # Home
    "home_screen.dart": "home",
    "smart_recommendations_row.dart": "home",
    "home_provider.dart": "home",
    
    # Search
    "search_screen.dart": "search",
    "search_provider.dart": "search",
    
    # Player (Audio, Video, Lyrics)
    "now_playing_screen.dart": "player",
    "fullscreen_video_screen.dart": "player",
    "queue_bottom_sheet.dart": "player",
    "sleep_timer_sheet.dart": "player",
    "lyrics_screen.dart": "player",
    "video_player_screen.dart": "player",
    "video_tab_screen.dart": "player",
    "audio_player_provider.dart": "player",
    "video_player_provider.dart": "player",
    "lyrics_provider.dart": "player",
    
    # Library
    "library_screen.dart": "library",
    "artist_detail_screen.dart": "library",
    "playlist_detail_screen.dart": "library",
    "custom_playlist_detail_screen.dart": "library",
    "see_all_screen.dart": "library",
    "custom_playlist_provider.dart": "library",
    "listening_history_provider.dart": "library",
    "download_provider.dart": "library",
    
    # Settings
    "settings_screen.dart": "settings",
    "audio_settings_screen.dart": "settings",
    "profile_screen.dart": "settings",
    "hidden_songs_screen.dart": "settings",
    "settings_provider.dart": "settings",
    "profile_provider.dart": "settings",
    "hidden_songs_provider.dart": "settings",
    
    # AI
    "ask_ai_screen.dart": "ai",
    "ai_settings_provider.dart": "ai",
    
    # Social/Room
    "room_bottom_sheet.dart": "social",
    "room_service.dart": "social",
    
    # Subscription
    "paywall_bottom_sheet.dart": "subscription",
    "subscription_provider.dart": "subscription",

    # Core Widgets
    "custom_image_widget.dart": "core/widgets",
    "hero_collage.dart": "core/widgets",
    "import_progress_banner.dart": "core/widgets",
    "mini_player.dart": "core/widgets",
    "song_options_sheet.dart": "core/widgets",
    "wavy_seek_bar.dart": "core/widgets"
}

def get_new_rel_path(basename):
    domain = feature_map.get(basename)
    if domain:
        if domain.startswith("core"):
            return f"{domain}/{basename}"
        return f"features/{domain}/{basename}"
    return None

def move_files():
    print("Moving files to feature directories...")
    # Scan lib for files to move
    moved_count = 0
    for root, dirs, files in os.walk(base_dir):
        # Skip features dir to avoid moving already moved files
        if "features" in root.split(os.sep) or "core\\widgets" in root:
            continue
            
        for file in files:
            if file in feature_map:
                old_path = os.path.join(root, file)
                new_rel = get_new_rel_path(file)
                new_path = os.path.join(base_dir, os.path.normpath(new_rel))
                
                os.makedirs(os.path.dirname(new_path), exist_ok=True)
                shutil.move(old_path, new_path)
                moved_count += 1
                print(f"Moved: {file} -> {new_rel}")
    print(f"Total files moved: {moved_count}")

def update_imports():
    print("Updating import paths...")
    import_pattern = re.compile(r"import\s+['\"]([^'\"]+)['\"](\s+as\s+\w+)?\s*;")
    
    target_dirs = [base_dir, test_dir]
    updated_files = 0
    
    for t_dir in target_dirs:
        for root, dirs, files in os.walk(t_dir):
            for file in files:
                if not file.endswith(".dart"):
                    continue
                    
                filepath = os.path.join(root, file)
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                new_content = content
                
                # Find all imports
                matches = import_pattern.finditer(content)
                for match in matches:
                    full_import = match.group(0)
                    import_path = match.group(1)
                    as_clause = match.group(2) or ""
                    
                    basename = os.path.basename(import_path)
                    
                    # If this imported file was moved
                    if basename in feature_map:
                        new_rel = get_new_rel_path(basename)
                        new_import_str = f"import 'package:it_feels_music/{new_rel.replace('\\', '/')}'{as_clause};"
                        new_content = new_content.replace(full_import, new_import_str)
                        
                if content != new_content:
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    updated_files += 1
                    
    print(f"Updated imports in {updated_files} files.")

if __name__ == "__main__":
    move_files()
    update_imports()
    print("Architecture refactor complete!")
