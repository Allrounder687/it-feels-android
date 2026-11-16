import 'package:flutter/material.dart';
import 'package:it_feels_music/core/widgets/collection_download_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/intelligence/playlists/listening_collection_service.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import '../theme/content_viewport_insets.dart';
import '../theme/new_experience_tokens.dart';
import '../widgets/new_artwork_image.dart';
import '../widgets/new_card.dart';
import '../widgets/new_media_tile.dart';
import '../widgets/new_section_header.dart';

final listeningCollectionServiceProvider = Provider<ListeningCollectionService>(
  (ref) => ListeningCollectionService(locator<IMusicRepository>()),
);

String collectionSection(ListeningCollectionKind kind) => switch (kind) {
  ListeningCollectionKind.artist => 'Artist mixes',
  ListeningCollectionKind.year => 'Travel by year',
  ListeningCollectionKind.decade => 'Decade essentials',
  ListeningCollectionKind.mood => 'Find your mood',
  ListeningCollectionKind.genre => 'Explore genres',
  ListeningCollectionKind.album => 'Rediscover albums',
  ListeningCollectionKind.radio => 'Your song radio stations',
};

class NewListeningCollections extends StatelessWidget {
  final List<Song> songs;
  final List<String> favoriteArtists;
  const NewListeningCollections({
    super.key,
    required this.songs,
    this.favoriteArtists = const [],
  });

  @override
  Widget build(BuildContext context) {
    final catalogue = ListeningCollection.catalogue(
      songs,
      favoriteArtists: favoriteArtists,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final kind in ListeningCollectionKind.values)
          if (catalogue.any((c) => c.kind == kind)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: NewSectionHeader(
                title: collectionSection(kind),
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NewCollectionBrowseScreen(
                      collections: catalogue
                          .where((c) => c.kind == kind)
                          .toList(),
                      artworkSongs: songs,
                      title: collectionSection(kind),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height:
                  164 +
                  MediaQuery.textScalerOf(context).scale(14) * 1.35 +
                  MediaQuery.textScalerOf(context).scale(12.5) * 1.3 +
                  24,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: catalogue
                    .where((c) => c.kind == kind)
                    .take(8)
                    .length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) => _collectionCard(
                  context,
                  catalogue.where((c) => c.kind == kind).elementAt(index),
                  songs,
                  164,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

Widget _collectionCard(
  BuildContext context,
  ListeningCollection collection,
  List<Song> songs,
  double width,
) {
  final matching = ListeningCollectionService.select(collection, songs);
  final cover = collection.seed?.coverArt ?? matching.firstOrNull?.coverArt;
  void open() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => NewListeningStationScreen(collection: collection),
    ),
  );
  return NewCard(
    title: collection.title,
    subtitle: collection.subtitle,
    width: width,
    imageUrl: cover,
    onTap: open,
    customArtwork: cover == null || cover.isEmpty
        ? _CollectionCover(collection: collection)
        : null,
  );
}

class _CollectionCover extends StatelessWidget {
  final ListeningCollection collection;
  const _CollectionCover({required this.collection});
  @override
  Widget build(BuildContext context) {
    final colors = [
      NewExperienceTokens.accentViolet,
      NewExperienceTokens.accentCyan,
      NewExperienceTokens.accentRose,
      NewExperienceTokens.accentEmerald,
      NewExperienceTokens.accentAmber,
    ];
    final color =
        colors[collection.title.codeUnits.fold<int>(0, (a, b) => a + b) %
            colors.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, NewExperienceTokens.midnightSurface],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              collection.kind == ListeningCollectionKind.radio
                  ? Icons.sensors
                  : Icons.graphic_eq,
              color: Colors.white,
              size: 28,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  collection.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewCollectionBrowseScreen extends ConsumerWidget {
  final List<ListeningCollection> collections;
  final List<Song> artworkSongs;
  final String title;
  const NewCollectionBrowseScreen({
    super.key,
    required this.collections,
    required this.artworkSongs,
    required this.title,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: NewExperienceTokens.obsidianBackground,
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = ((constraints.maxWidth - 24) / 180).floor().clamp(
            1,
            8,
          );
          final width =
              (constraints.maxWidth - 40 - (columns - 1) * 14) / columns;
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              ContentViewportInsets.bottom(context, ref),
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent:
                  width +
                  MediaQuery.textScalerOf(context).scale(14) * 1.35 +
                  MediaQuery.textScalerOf(context).scale(12.5) * 1.3 +
                  24,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
            ),
            itemCount: collections.length,
            itemBuilder: (context, index) => _collectionCard(
              context,
              collections[index],
              artworkSongs,
              width,
            ),
          );
        },
      ),
    ),
  );
}

class NewListeningStationScreen extends ConsumerStatefulWidget {
  final ListeningCollection collection;
  const NewListeningStationScreen({super.key, required this.collection});
  @override
  ConsumerState<NewListeningStationScreen> createState() =>
      _NewListeningStationScreenState();
}

class _NewListeningStationScreenState
    extends ConsumerState<NewListeningStationScreen> {
  List<Song> _songs = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tracks = await ref
          .read(listeningCollectionServiceProvider)
          .load(widget.collection, refresh: refresh);
      if (mounted) setState(() => _songs = tracks);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not load songs. Check your connection and music addons.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.read(audioPlayerProvider.notifier);
    return Scaffold(
      backgroundColor: NewExperienceTokens.obsidianBackground,
      appBar: AppBar(
        title: Text(widget.collection.title),
        actions: [
          IconButton(
            tooltip: 'Refresh collection',
            onPressed: _loading ? null : () => _load(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _load(refresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _songs.isEmpty
                              ? _CollectionCover(collection: widget.collection)
                              : NewArtworkImage(
                                  imageUrl: _songs.first.coverArt,
                                  fallbackTitle: widget.collection.title,
                                  width: 180,
                                  height: 180,
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.collection.subtitle,
                        style: NewExperienceTokens.bodyMedium(),
                      ),
                      const SizedBox(height: 12),
                      if (_songs.isNotEmpty)
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () => player.playSong(
                                _songs.first,
                                queue: _songs,
                                index: 0,
                              ),
                              icon: const Icon(Icons.play_arrow),
                              label: Text('Play ${_songs.length} songs'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  player.shufflePlayContext(_songs),
                              icon: const Icon(Icons.shuffle),
                              label: const Text('Shuffle'),
                            ),
                            CollectionDownloadButton(collectionId: widget.collection.id, title: widget.collection.title, songs: _songs),
                          ],
                        ),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: LinearProgressIndicator(),
                        ),
                      if (_error != null || (!_loading && _songs.isEmpty)) ...[
                        Text(
                          _error ??
                              'No matching songs from your installed addons yet. Try another collection or refresh.',
                          style: NewExperienceTokens.bodyMedium(),
                        ),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => _load(refresh: true),
                          child: const Text('Try again'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: _songs.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: NewMediaTile(
                    song: _songs[index],
                    index: index,
                    onTap: () => player.playSong(
                      _songs[index],
                      queue: _songs,
                      index: index,
                    ),
                  ),
                ),
              ),
              ContentViewportInsets.sliverBottomSpacer(context, ref),
            ],
          ),
        ),
      ),
    );
  }
}
