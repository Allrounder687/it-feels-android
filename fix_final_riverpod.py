import os

search_screen = r"d:\Organized_Downloads\Projects\Kreo Projects\IT-Feels\lib\features\search\search_screen.dart"
with open(search_screen, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("Widget build(BuildContext context, WidgetRef ref)", "Widget build(BuildContext context)")

old_consumer = """Consumer3<SearchProvider, AudioPlayerProvider, HiddenSongsProvider>(
      builder: (context, searchProvider, playerProvider, hiddenProvider, child) {"""
new_builder = """Builder(
      builder: (context) {
        final searchProviderObj = ref.watch(searchProvider);
        final playerProviderObj = ref.watch(audioPlayerProvider);
        final hiddenProviderObj = ref.watch(hiddenSongsProvider);"""
content = content.replace(old_consumer, new_builder)

content = content.replace("final settingsProvider = ref.watch(settingsProvider);", "final settingsProviderObj = ref.watch(settingsProvider);")
content = content.replace("settingsProvider.enableMusicVideos", "settingsProviderObj.enableMusicVideos")

content = content.replace("searchProvider.", "searchProviderObj.")
content = content.replace("playerProvider.", "playerProviderObj.")
content = content.replace("hiddenProvider.", "hiddenProviderObj.")

with open(search_screen, 'w', encoding='utf-8') as f:
    f.write(content)

video_tab_screen = r"d:\Organized_Downloads\Projects\Kreo Projects\IT-Feels\lib\features\player\video_tab_screen.dart"
with open(video_tab_screen, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("Widget build(BuildContext context, WidgetRef ref)", "Widget build(BuildContext context)")

with open(video_tab_screen, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed search_screen.dart and video_tab_screen.dart")
