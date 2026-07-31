import os
import shutil
import re

base_dir = r"d:\Organized_Downloads\Projects\Kreo Projects\IT-Feels\lib"
test_dir = r"d:\Organized_Downloads\Projects\Kreo Projects\IT-Feels\test"

missing_feature_map = {
    "driving_mode_screen.dart": "features/home",
    "lyrics_share_dialog.dart": "features/player",
    "ai_settings_screen.dart": "features/ai",
    "stats_screen.dart": "features/settings",
    "animated_equalizer.dart": "core/widgets",
    "animated_play_pause_button.dart": "core/widgets",
    "bouncy_icon_button.dart": "core/widgets"
}

def move_missing_files():
    # Remove the restored main_navigation_wrapper.dart since we have it in core/router
    wrapper_path = os.path.join(base_dir, "views", "main_navigation_wrapper.dart")
    if os.path.exists(wrapper_path):
        os.remove(wrapper_path)
        
    for root, dirs, files in os.walk(os.path.join(base_dir, "views")):
        for file in files:
            if file in missing_feature_map:
                old_path = os.path.join(root, file)
                new_rel = f"{missing_feature_map[file]}/{file}"
                new_path = os.path.join(base_dir, os.path.normpath(new_rel))
                
                os.makedirs(os.path.dirname(new_path), exist_ok=True)
                shutil.move(old_path, new_path)
                print(f"Moved: {file} -> {new_rel}")
                
    # Clean up views directory
    shutil.rmtree(os.path.join(base_dir, "views"), ignore_errors=True)

def update_missing_imports():
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
                
                matches = import_pattern.finditer(content)
                for match in matches:
                    full_import = match.group(0)
                    import_path = match.group(1)
                    as_clause = match.group(2) or ""
                    
                    basename = os.path.basename(import_path)
                    
                    if basename in missing_feature_map:
                        new_rel = f"{missing_feature_map[basename]}/{basename}"
                        new_import_str = f"import 'package:it_feels_music/{new_rel}'{as_clause};"
                        new_content = new_content.replace(full_import, new_import_str)
                        
                if content != new_content:
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    updated_files += 1
                    
    print(f"Updated missing imports in {updated_files} files.")

if __name__ == "__main__":
    move_missing_files()
    update_missing_imports()
