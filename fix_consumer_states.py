import os

base = r"d:\Organized_Downloads\Projects\Kreo Projects\IT-Feels\lib\features"
files = [
    r"settings\audio_settings_screen.dart",
    r"settings\profile_screen.dart",
    r"settings\stats_screen.dart",
    r"social\room_bottom_sheet.dart",
    r"subscription\paywall_bottom_sheet.dart"
]

for f in files:
    path = os.path.join(base, f)
    with open(path, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # Fix ConsumerState invalid override
    content = content.replace("Widget build(BuildContext context, WidgetRef ref)", "Widget build(BuildContext context)")
    
    with open(path, 'w', encoding='utf-8') as file:
        file.write(content)

print("Fixed ConsumerState overrides")
