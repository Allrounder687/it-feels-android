import os

base_dir = r"d:\Organized_Downloads\Projects\Kreo Projects\IT-Feels\lib"

replacements = {
    "package:it_feels_music/features/services/": "package:it_feels_music/services/",
    "package:it_feels_music/features/data/": "package:it_feels_music/data/",
    "package:it_feels_music/features/utils/": "package:it_feels_music/core/utils/",
    "package:it_feels_music/features/providers/": "package:it_feels_music/features/",
    # In case there are any others
}

updated_files = 0

for root, dirs, files in os.walk(base_dir):
    for file in files:
        if not file.endswith(".dart"): continue
        filepath = os.path.join(root, file)
        
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        new_content = content
        
        for old_str, new_str in replacements.items():
            new_content = new_content.replace(old_str, new_str)
            
        if content != new_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            updated_files += 1

print(f"Fixed broken absolute imports in {updated_files} files.")
