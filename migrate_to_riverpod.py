import os
import re

base_dir = r"d:\Organized_Downloads\Projects\Kreo Projects\IT-Feels\lib"

def to_camel(s):
    if not s: return s
    # e.g. AudioPlayerProvider -> audioPlayerProvider
    # wait, the providers in the bridge are camelCase but without 'Provider' at the end?
    # No, I named them audioPlayerProvider, homeProvider, etc.
    # So we just lowercase the first letter.
    return s[0].lower() + s[1:]

def migrate_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content
    
    if "package:provider/provider.dart" not in content and "ConsumerWidget" not in content:
        return False

    # 1. Imports
    content = content.replace("import 'package:provider/provider.dart';", 
        "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:it_feels_music/core/providers/riverpod_bridge.dart';")

    # 2. StatelessWidget -> ConsumerWidget
    content = re.sub(r'class\s+(\w+)\s+extends\s+StatelessWidget', r'class \1 extends ConsumerWidget', content)
    
    # 3. build(BuildContext context) -> build(BuildContext context, WidgetRef ref)
    # Be careful with multiline or other signatures.
    # Usually it's `Widget build(BuildContext context) {` or `Widget build(BuildContext context) =>`
    content = re.sub(r'Widget\s+build\(\s*BuildContext\s+context\s*\)', r'Widget build(BuildContext context, WidgetRef ref)', content)

    # 4. StatefulWidget -> ConsumerStatefulWidget
    content = re.sub(r'class\s+(\w+)\s+extends\s+StatefulWidget', r'class \1 extends ConsumerStatefulWidget', content)
    
    # 5. State<T> -> ConsumerState<T>
    content = re.sub(r'extends\s+State<(\w+)>', r'extends ConsumerState<\1>', content)
    # State constructor: `State<MyWidget> createState() => _MyWidgetState();`
    content = re.sub(r'State<(\w+)>\s+createState\(\)', r'ConsumerState<\1> createState()', content)

    # 6. Provider.of<T>(context, listen: false) -> ref.read(tProvider)
    #    Provider.of<T>(context) -> ref.watch(tProvider)
    def provider_of_replacer(match):
        provider_class = match.group(1)
        listen_clause = match.group(2)
        provider_var = to_camel(provider_class)
        if listen_clause and "false" in listen_clause:
            return f"ref.read({provider_var})"
        return f"ref.watch({provider_var})"
        
    content = re.sub(r'Provider\.of<(\w+)>\(context(,\s*listen\s*:\s*(true|false))?\)', provider_of_replacer, content)

    # 7. context.watch<T>() -> ref.watch(tProvider)
    def context_watch_replacer(match):
        provider_class = match.group(1)
        return f"ref.watch({to_camel(provider_class)})"
    content = re.sub(r'context\.watch<(\w+)>\(\)', context_watch_replacer, content)

    # 8. context.read<T>() -> ref.read(tProvider)
    def context_read_replacer(match):
        provider_class = match.group(1)
        return f"ref.read({to_camel(provider_class)})"
    content = re.sub(r'context\.read<(\w+)>\(\)', context_read_replacer, content)

    # 9. Consumer<T>(builder: (context, val, child) { ... }) 
    # Riverpod Consumer builder takes (BuildContext context, WidgetRef ref, Widget? child)
    def consumer_replacer(match):
        provider_class = match.group(1)
        val_name = match.group(2)
        child_name = match.group(3)
        return f"Consumer(builder: (context, ref, {child_name}) {{ final {val_name} = ref.watch({to_camel(provider_class)}); "
    
    # Matching `Consumer<AudioPlayerProvider>(builder: (context, player, child) {`
    # We will just replace the declaration line.
    content = re.sub(r'Consumer<(\w+)>\(\s*builder:\s*\(\s*context\s*,\s*(\w+)\s*,\s*(\w+)\s*\)\s*\{', consumer_replacer, content)
    
    # Same for single-line fat arrows: `Consumer<T>(builder: (c, v, ch) => ...)`
    def consumer_arrow_replacer(match):
        provider_class = match.group(1)
        val_name = match.group(2)
        child_name = match.group(3)
        return f"Consumer(builder: (context, ref, {child_name}) {{ final {val_name} = ref.watch({to_camel(provider_class)}); return "
    
    content = re.sub(r'Consumer<(\w+)>\(\s*builder:\s*\(\s*context\s*,\s*(\w+)\s*,\s*(\w+)\s*\)\s*=>', consumer_arrow_replacer, content)

    if content != original_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False

updated = 0
for root, dirs, files in os.walk(base_dir):
    for file in files:
        if file.endswith(".dart"):
            filepath = os.path.join(root, file)
            if migrate_file(filepath):
                updated += 1
                print(f"Migrated: {filepath}")

print(f"\nTotal files migrated to Riverpod: {updated}")
