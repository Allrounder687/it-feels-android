import re

with open('lib/features/player/widgets/live_lyrics_preview_card.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove final Duration position;
content = content.replace("  final Duration position;\n", "")
# 2. Remove required this.position,
content = content.replace("    required this.position,\n", "")

# 3. Replace the middle part with StreamBuilder
# Find the start of the logic
start_str = """    String prevLine = "";
    String currentLine = "";
    String nextLine = "";"""

# Find the end of the build method
end_str = """    );
  }
}
"""

replacement_start = """    return ExcludeSemantics(
      child: StreamBuilder<Duration>(
        stream: ref.read(audioPlayerProvider.notifier).engine.positionStream,
        initialData: ref.read(audioPlayerProvider.notifier).engine.position,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;

          String prevLine = "";
          String currentLine = "";
          String nextLine = "";"""

replacement_end = """        );
      },
      ),
    );
  }
}
"""

content = content.replace(start_str, replacement_start)
content = content.replace(end_str, replacement_end)

# Also fix the return GestureDetector to just return it, wait, it's already return GestureDetector.
# Let's replace '    return GestureDetector(' with '          return GestureDetector('
content = content.replace("    return GestureDetector(", "          return GestureDetector(")

with open('lib/features/player/widgets/live_lyrics_preview_card.dart', 'w', encoding='utf-8') as f:
    f.write(content)
