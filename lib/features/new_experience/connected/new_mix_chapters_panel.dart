import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/utils/audio_source_policy.dart';
import 'package:it_feels_music/core/widgets/collection_download_button.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/features/connected_music/connected_music_models.dart';
import 'package:it_feels_music/features/discovery/mix_chapter_service.dart';
import '../playlist/new_playlist_detail_screen.dart';
import '../theme/new_experience_tokens.dart';

class NewMixChaptersPanel extends ConsumerStatefulWidget {
  final RemotePlaylist playlist;
  final AccountSnapshot snapshot;
  const NewMixChaptersPanel({
    super.key,
    required this.playlist,
    required this.snapshot,
  });
  @override
  ConsumerState<NewMixChaptersPanel> createState() =>
      _NewMixChaptersPanelState();
}

class _NewMixChaptersPanelState extends ConsumerState<NewMixChaptersPanel> {
  List<ChapterMatch>? _matches;
  Future<List<ChapterMatch>>? _operation;
  bool _playing = false, _expanded = false;
  int _chapterGeneration = 0;
  String? _message;
  @override
  void didUpdateWidget(covariant NewMixChaptersPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.snapshot.chapters
        .map((c) => '${c.startSeconds}:${c.endSeconds}:${c.title}')
        .join('|');
    final after = widget.snapshot.chapters
        .map((c) => '${c.startSeconds}:${c.endSeconds}:${c.title}')
        .join('|');
    if (before != after) {
      _chapterGeneration++;
      _matches = null;
      _operation = null;
      _message = null;
    }
  }

  String get _savedId => 'chapter_mix_${widget.playlist.videoId}';
  Future<List<ChapterMatch>> _resolve(
    IMusicRepository repository,
    Future<void> Function(List<Song>) save,
  ) {
    if (_matches != null) return Future.value(_matches!);
    if (_operation != null) return _operation!;
    final chapters = List.of(widget.snapshot.chapters);
    if (chapters.isEmpty) {
      throw const FormatException('Chapter metadata is not available');
    }
    final generation = _chapterGeneration;
    final operation = () async {
      final matches = await MixChapterService(repository).resolve(chapters);
      if (generation != _chapterGeneration) {
        throw const FormatException('Chapter list changed; retry matching');
      }
      final songs = matches.map((m) => m.song).whereType<Song>().toList();
      if (songs.isNotEmpty) await save(songs);
      if (mounted) {
        setState(() {
          _matches = matches;
          _message =
              '${songs.length}/${chapters.length} chapters matched. Unmatched chapters are not substituted.';
        });
      }
      return matches;
    }();
    _operation = operation;
    if (mounted) setState(() {});
    return operation.whenComplete(() {
      if (generation == _chapterGeneration) {
        _operation = null;
        if (mounted) setState(() {});
      }
    });
  }

  Future<void> _play(
    IMusicRepository repository,
    Future<void> Function(List<Song>) save, {
    int? chapter,
  }) async {
    if (_playing || widget.snapshot.tracks.isEmpty) return;
    setState(() => _playing = true);
    final container = ProviderScope.containerOf(context, listen: false);
    final player = ref.read(audioPlayerProvider.notifier);
    final full = widget.snapshot.tracks.first.song;
    final activeId = ref.read(audioPlayerProvider).currentSong?.id;
    final start = chapter == null || widget.snapshot.chapters.isEmpty
        ? 0
        : widget.snapshot.chapters[chapter].startSeconds;
    try {
      String? source;
      if (activeId == full.id) {
        source = 'active';
      } else {
        try {
          source = await repository
              .getStreamUrl(full)
              .timeout(const Duration(seconds: 20));
        } catch (_) {
          /* Try chapters when source resolution fails. */
        }
      }
      if (source != null &&
          source.isNotEmpty &&
          (source == 'active' || await AudioSourcePolicy.probe(source))) {
        if (container.read(audioPlayerProvider).currentSong?.id != activeId) {
          return;
        }
        if (activeId != full.id) {
          await player.playSong(
            full,
            queue: [full],
            predefinedStreamUrl: source,
          );
        }
        await player.seek(Duration(seconds: start));
        if (!container.read(audioPlayerProvider).isPlaying) {
          await player.togglePlayPause();
        }
      } else {
        final matches = await _resolve(repository, save);
        final songs = matches.map((m) => m.song).whereType<Song>().toList();
        if (songs.isEmpty) throw const FormatException('No chapter matches');
        if (container.read(audioPlayerProvider).currentSong?.id != activeId) {
          return;
        }
        final target = matches.isNotEmpty
            ? matches[(chapter ?? 0).clamp(0, matches.length - 1)].song
            : null;
        final index = target == null ? 0 : songs.indexOf(target);
        await player.playSong(
          songs[index < 0 ? 0 : index],
          queue: songs,
          index: index < 0 ? 0 : index,
        );
        if (mounted) {
          setState(
            () => _message =
                'The full mix source is unavailable. Playing the matched chapter playlist instead.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not play this mix. Try building its track playlist or check your playback addons.',
        );
      }
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = locator<IMusicRepository>();
    final playlists = ref.read(customPlaylistProvider.notifier);
    final id = _savedId, title = 'Tracks from ${widget.playlist.title}';
    Future<void> save(List<Song> songs) =>
        playlists.upsertPlaylistWithSongs(id, title, songs);
    final snapshot = widget.snapshot;
    final full = snapshot.tracks.firstOrNull?.song;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _playing || full == null
                  ? null
                  : () => _play(repository, save),
              icon: const Icon(Icons.headphones_rounded),
              label: Text(_playing ? 'Preparing audio…' : 'Play full mix'),
            ),
            CollectionDownloadButton(
              collectionId: widget.playlist.key,
              title: widget.playlist.title,
              loadSongs: full == null || !snapshot.complete
                  ? null
                  : () async {
                      try {
                        final source = await repository
                            .getStreamUrl(full)
                            .timeout(const Duration(seconds: 20));
                        if (source != null &&
                            source.isNotEmpty &&
                            await AudioSourcePolicy.probe(source)) {
                          return [full];
                        }
                      } catch (_) {
                        /* Fall back to the real tracks named by the creator. */
                      }
                      final matches = await _resolve(repository, save);
                      final songs = matches
                          .map((m) => m.song)
                          .whereType<Song>()
                          .toList();
                      if (songs.isEmpty) {
                        throw const FormatException(
                          'No downloadable mix or chapter tracks',
                        );
                      }
                      return songs;
                    },
            ),
            OutlinedButton.icon(
              onPressed: snapshot.chapters.isEmpty || _operation != null
                  ? null
                  : () async {
                      try {
                        await _resolve(repository, save);
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () => _message =
                                'Chapter matching could not finish. Please retry.',
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.playlist_add_rounded),
              label: Text(
                _operation != null
                    ? 'Matching tracks…'
                    : 'Build track playlist',
              ),
            ),
          ],
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_message!, style: NewExperienceTokens.bodySmall()),
          ),
        if (_matches?.any((m) => m.song != null) == true)
          TextButton.icon(
            onPressed: () {
              final songs = _matches!
                  .map((m) => m.song)
                  .whereType<Song>()
                  .toList();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NewPlaylistDetailScreen(
                    playlist: Playlist(
                      id: id,
                      title: title,
                      songCount: songs.length,
                      songs: songs,
                    ),
                    staticTracks: songs,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.queue_music_rounded),
            label: const Text('Open saved track playlist'),
          ),
        const SizedBox(height: 16),
        Text('Chapters', style: NewExperienceTokens.sectionTitle(fontSize: 18)),
        if (snapshot.chapters.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No usable chapters or timestamped track list was provided. The app will not guess which songs are in the mix.',
              style: NewExperienceTokens.bodySmall(),
            ),
          ),
        for (
          var i = 0;
          i <
              (_expanded
                  ? snapshot.chapters.length
                  : snapshot.chapters.length.clamp(0, 8));
          i++
        )
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(
              '${snapshot.chapters[i].startSeconds ~/ 60}:${(snapshot.chapters[i].startSeconds % 60).toString().padLeft(2, '0')}',
              style: NewExperienceTokens.bodySmall(),
            ),
            title: Text(
              snapshot.chapters[i].title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: NewExperienceTokens.bodyMedium(),
            ),
            subtitle: _matches == null
                ? null
                : Text(
                    _matches![i].song?.artist ?? 'No reliable catalogue match',
                    style: NewExperienceTokens.bodySmall(),
                  ),
            onTap: _playing ? null : () => _play(repository, save, chapter: i),
            trailing: _matches == null || _matches![i].song == null
                ? const Icon(Icons.play_arrow_rounded)
                : CollectionDownloadButton(
                    collectionId: 'track:${_matches![i].song!.id}',
                    title: _matches![i].song!.title,
                    songs: [_matches![i].song!],
                    iconOnly: true,
                  ),
          ),
        if (snapshot.chapters.length > 8)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded
                  ? 'Show fewer chapters'
                  : 'Show all ${snapshot.chapters.length} chapters',
            ),
          ),
      ],
    );
  }
}
