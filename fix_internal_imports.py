import os
import re

base_dir = r"d:\Organized_Downloads\Projects\Kreo Projects\IT-Feels\lib"

def resolve_import(filepath, import_path):
    file_dir = os.path.dirname(filepath)
    resolved_abs = os.path.normpath(os.path.join(file_dir, import_path))
    
    if resolved_abs.startswith(base_dir):
        rel_to_lib = os.path.relpath(resolved_abs, base_dir)
        return f"package:it_feels_music/{rel_to_lib.replace(os.sep, '/')}"
    return None

updated_files = 0
for root, dirs, files in os.walk(base_dir):
    for file in files:
        if not file.endswith(".dart"): continue
        filepath = os.path.join(root, file)
        
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        new_content = content
        
        matches = re.finditer(r"import\s+['\"](\.\./[^'\"]+)['\"](\s+as\s+\w+)?\s*;", content)
        for match in matches:
            full_match = match.group(0)
            rel_path = match.group(1)
            as_clause = match.group(2) or ""
            
            pkg_path = resolve_import(filepath, rel_path)
            if pkg_path:
                new_import = f"import '{pkg_path}'{as_clause};"
                new_content = new_content.replace(full_match, new_import)
                
        if content != new_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            updated_files += 1

print(f"Fixed relative imports in {updated_files} files.")
