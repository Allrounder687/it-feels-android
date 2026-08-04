import os
import glob

import_statement = "import 'package:it_feels_music/core/theme/app_dimensions.dart';"

def process_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    if '168 + MediaQuery.of(context).viewPadding.bottom' in content:
        content = content.replace('168 + MediaQuery.of(context).viewPadding.bottom', 'AppDimensions.bottomClearance + MediaQuery.of(context).viewPadding.bottom')
        
        # Add import if not present
        if 'app_dimensions.dart' not in content:
            # Find the last import statement
            lines = content.split('\n')
            last_import_index = -1
            for i, line in enumerate(lines):
                if line.startswith('import '):
                    last_import_index = i
            
            if last_import_index != -1:
                lines.insert(last_import_index + 1, import_statement)
                content = '\n'.join(lines)
            else:
                content = import_statement + '\n' + content

        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'Updated {file_path}')

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
