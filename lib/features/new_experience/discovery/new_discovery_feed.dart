import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/intelligence/ai/ai_discovery_orchestrator.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/widgets/collection_download_button.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/features/connected_music/connected_music_providers.dart';
import 'package:it_feels_music/features/discovery/discovery_feed_service.dart';
import 'package:it_feels_music/features/discovery/mix_chapter_service.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart'
    show customPlaylistProvider;
import '../connected/new_connected_accounts.dart';
import '../playlist/new_playlist_detail_screen.dart';
import '../widgets/new_card.dart';
import '../theme/new_experience_tokens.dart';

final discoveryFeedProvider = ChangeNotifierProvider<DiscoveryFeedService>((
  ref,
) {
  final repository = locator<IMusicRepository>();
  final service = DiscoveryFeedService(
    repository,
    publicGateway: ref.watch(accountBrowserGatewayProvider),
    generate: (prompt) async => (await AIDiscoveryOrchestrator(
      musicRepo: repository,
    ).discoverAndValidate(prompt: prompt, count: 30)).songs,
  );
  unawaited(service.refresh());
  final timer = Timer.periodic(
    const Duration(hours: 6),
    (_) => unawaited(service.refresh()),
  );
  ref.onDispose(timer.cancel);
  return service;
});

class NewDiscoveryFeed extends ConsumerStatefulWidget {
  const NewDiscoveryFeed({super.key});
  @override
  ConsumerState<NewDiscoveryFeed> createState() => _NewDiscoveryFeedState();
}

class _NewDiscoveryFeedState extends ConsumerState<NewDiscoveryFeed>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(discoveryFeedProvider).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(discoveryFeedProvider);
    final accountService = ref.read(connectedMusicProvider);
    final repository = locator<IMusicRepository>();
    final savedPlaylists = ref.read(customPlaylistProvider.notifier);
    void openMix(List<Song> songs, String id, String title) =>
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NewPlaylistDetailScreen(
              playlist: Playlist(
                id: id,
                title: title,
                songCount: songs.length,
                songs: songs,
                coverArt: songs.firstOrNull?.coverArt ?? '',
              ),
              staticTracks: songs,
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FIND YOUR NEXT FAVORITE',
                  style: NewExperienceTokens.eyebrowLabel(),
                ),
                const SizedBox(height: 6),
                Text(
                  'No taste profile? Start anywhere.',
                  style: NewExperienceTokens.sectionTitle(),
                ),
                const SizedBox(height: 6),
                Text(
                  'Real playlists, different sounds. Discover what you like as you listen.',
                  style: NewExperienceTokens.bodySmall(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: feed.sampler.isEmpty
                          ? null
                          : () => openMix(
                              feed.sampler,
                              'discovery_sampler',
                              'A little of everything',
                            ),
                      icon: const Icon(Icons.explore_rounded),
                      label: const Text('A little of everything'),
                    ),
                    OutlinedButton.icon(
                      onPressed: feed.generating
                          ? null
                          : () async {
                              await feed.surprise();
                              if (context.mounted &&
                                  feed.generated.isNotEmpty) {
                                openMix(
                                  feed.generated,
                                  'discovery_surprise',
                                  'Your surprise selection',
                                );
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'No tracks available yet. Try refreshing discovery.',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        feed.generating
                            ? 'Finding something new…'
                            : 'Surprise me',
                      ),
                    ),
                    IconButton(
                      onPressed: feed.loading
                          ? null
                          : () => feed.refresh(force: true),
                      tooltip: 'Refresh discoveries',
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                if (feed.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: LinearProgressIndicator(),
                  ),
                if (feed.message != null)
                  Text(feed.message!, style: NewExperienceTokens.bodySmall()),
              ],
            ),
          ),
          for (final category in feed.picks.map((p) => p.category).toSet()) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Text(
                category,
                style: NewExperienceTokens.sectionTitle(fontSize: 18),
              ),
            ),
            SizedBox(
              height:
                  164 +
                  MediaQuery.textScalerOf(context).scale(14) * 2.7 +
                  MediaQuery.textScalerOf(context).scale(12.5) * 1.6 +
                  78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: feed.picks
                    .where((p) => p.category == category)
                    .length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final pick = feed.picks
                      .where((p) => p.category == category)
                      .elementAt(index);
                  return SizedBox(
                    width: 164,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        NewCard(
                          title: pick.title,
                          subtitle: pick.source,
                          imageUrl: pick.artwork,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => pick.remote != null
                                  ? NewConnectedPlaylistScreen(
                                      playlist: pick.remote!,
                                    )
                                  : NewPlaylistDetailScreen(
                                      playlist: pick.catalogue!,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        CollectionDownloadButton(
                          collectionId: pick.key,
                          title: pick.title,
                          loadSongs: () async {
                            final remote = pick.remote;
                            if (remote == null) {
                              return repository.getPlaylistTracks(
                                pick.catalogue!.id,
                              );
                            }
                            final snapshot = await loadRemoteSnapshot(
                              accountService.playlist(remote),
                            );
                            if (remote.videoId == null) {
                              return snapshot.tracks
                                  .map((t) => t.song)
                                  .toList();
                            }
                            final mix = await MixChapterService(
                              repository,
                            ).downloadable(snapshot);
                            if (mix.chapterCount != null) {
                              await savedPlaylists.upsertPlaylistWithSongs(
                                'chapter_mix_${remote.videoId}',
                                'Tracks from ${remote.title} (${mix.tracks.length}/${mix.chapterCount} matched)',
                                mix.tracks,
                              );
                            }
                            return mix.tracks;
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
