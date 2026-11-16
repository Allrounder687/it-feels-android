import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:it_feels_music/core/widgets/collection_download_button.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/connected_music/account_browser_gateway.dart';
import 'package:it_feels_music/features/connected_music/connected_music_models.dart';
import 'package:it_feels_music/features/connected_music/connected_music_providers.dart';
import '../theme/new_experience_tokens.dart';
import '../theme/content_viewport_insets.dart';
import '../widgets/new_artwork_image.dart';
import '../widgets/new_card.dart';
import 'new_mix_chapters_panel.dart';

Future<List<Song>> loadRemoteCollection(Stream<AccountSnapshot> pages) async {
  return (await loadRemoteSnapshot(pages)).tracks.map((t) => t.song).toList();
}

Future<AccountSnapshot> loadRemoteSnapshot(Stream<AccountSnapshot> pages) async {
  AccountSnapshot? last;
  await for (final snapshot in pages) {
    last = snapshot;
    if (snapshot.error != null) throw const AccountAccessException();
  }
  if (last?.complete != true) throw const AccountAccessException();
  return last!;
}

class NewConnectedAccountsScreen extends ConsumerWidget {
  const NewConnectedAccountsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(connectedMusicProvider);
    return Scaffold(
      backgroundColor: NewExperienceTokens.obsidianBackground,
      appBar: AppBar(
        title: const Text('Connected music'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.hub_rounded,
                size: 48,
                color: NewExperienceTokens.accentViolet,
              ),
              const SizedBox(height: 20),
              Text(
                'Your music.\nAlready here.',
                style: NewExperienceTokens.displayHero(fontSize: 34),
              ),
              const SizedBox(height: 12),
              Text(
                'Connect once. Your saved playlists appear on Home and stay connected to their creators.',
                style: NewExperienceTokens.bodyMedium(
                  color: NewExperienceTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              for (final addon in accountAddons) ...[
                _AccountCard(
                  addon: addon,
                  connection: service.account(addon.id),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'You sign in on the service’s own page. IT Feels stores your session securely on this device. '
                'These independent connections may need a fresh sign-in when the service changes. Audio availability depends on your installed playback addons.',
                style: NewExperienceTokens.bodySmall(),
              ),
              SizedBox(height: ContentViewportInsets.bottom(context, ref)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  final AccountAddon addon;
  final AccountConnection connection;
  const _AccountCard({required this.addon, required this.connection});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = connection.status == ConnectionStatus.refreshing;
    final linked = connection.linked;
    final reconnect = connection.status == ConnectionStatus.reconnect;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(addon.color).withValues(alpha: .12),
            NewExperienceTokens.cardSurface,
          ],
        ),
        border: Border.all(color: Color(addon.color).withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                addon.id == 'spotify'
                    ? Icons.graphic_eq_rounded
                    : Icons.play_circle_fill_rounded,
                size: 32,
                color: Color(addon.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  addon.name,
                  style: NewExperienceTokens.sectionTitle(),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (linked && !busy && !reconnect)
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(addon.color),
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            connection.message ??
                (linked
                    ? '${connection.name.isEmpty ? 'Connected' : connection.name} · ${connection.playlists.length} playlists'
                    : 'Your library, ready when you are.'),
            style: NewExperienceTokens.bodySmall(),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (!linked || reconnect)
                FilledButton.icon(
                  onPressed: AccountBrowserGateway.supported
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _AccountLoginScreen(addon: addon),
                          ),
                        )
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(addon.color),
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: Text(
                    reconnect ? 'Reconnect' : 'Connect ${addon.name}',
                  ),
                ),
              if (linked && !reconnect)
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => ref
                            .read(connectedMusicProvider)
                            .refresh(addon, force: true),
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('Refresh'),
                ),
              if (linked)
                TextButton(
                  onPressed: () async {
                    try {
                      await ref.read(connectedMusicProvider).disconnect(addon);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not clear the browser session. Please retry disconnecting.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Disconnect'),
                ),
            ],
          ),
          if (!AccountBrowserGateway.supported)
            Text(
              'Account sign-in is available on Android, iOS, macOS and Windows.',
              style: NewExperienceTokens.bodySmall(),
            ),
        ],
      ),
    );
  }
}

class _AccountLoginScreen extends ConsumerStatefulWidget {
  final AccountAddon addon;
  const _AccountLoginScreen({required this.addon});
  @override
  ConsumerState<_AccountLoginScreen> createState() =>
      _AccountLoginScreenState();
}

class _AccountLoginScreenState extends ConsumerState<_AccountLoginScreen> {
  late final AccountBrowserGateway gateway;
  late final Future<void> _ready;
  WebViewEnvironment? _environment;
  InAppWebViewController? _controller;
  Timer? _timer;
  bool _checking = false, _finishing = false;
  double _progress = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    gateway = ref.read(accountBrowserGatewayProvider);
    _ready = _prepare();
  }

  Future<void> _prepare() async {
    await gateway.install(widget.addon);
    _environment = await gateway.environment(widget.addon);
    await gateway.restore(widget.addon);
  }

  Future<void> _check() async {
    if (_checking || _finishing || !mounted || _controller == null) return;
    _checking = true;
    try {
      final snapshot = await gateway.snapshot(widget.addon, _controller!);
      if (snapshot?.authenticated != true || !mounted) return;
      _finishing = true;
      await gateway.remember(widget.addon);
      if (!mounted) return;
      final service = ref.read(connectedMusicProvider);
      // Publish immediately; background reader will finish the first feed automatically.
      unawaited(service.connected(widget.addon, snapshot!));
      Navigator.of(context).pop();
    } catch (_) {
      _finishing = false;
      if (mounted) {
        setState(
          () => _error =
              'Could not securely save this connection. Please try again.',
        );
      }
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: NewExperienceTokens.obsidianBackground,
    appBar: AppBar(title: Text('Connect ${widget.addon.name}')),
    body: FutureBuilder<void>(
      future: _ready,
      builder: (context, ready) {
        if (ready.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'The secure sign-in browser could not start. On Windows, check that Microsoft Edge WebView2 is installed.',
                style: NewExperienceTokens.bodyMedium(),
              ),
            ),
          );
        }
        if (ready.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: NewExperienceTokens.accentEmerald,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error ??
                          'Sign in below. Your playlists will appear automatically.',
                      style: NewExperienceTokens.bodySmall(),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _controller?.reload();
                    },
                    tooltip: 'Reload sign-in',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            if (_progress < 1) LinearProgressIndicator(value: _progress),
            Expanded(
              child: FutureBuilder(
                future: gateway.scripts(widget.addon),
                builder: (context, scripts) {
                  if (!scripts.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return InAppWebView(
                    webViewEnvironment: _environment,
                    initialSettings: gateway.settings,
                    initialUserScripts: scripts.data,
                    initialUrlRequest: URLRequest(
                      url: WebUri(widget.addon.loginUrl),
                    ),
                    shouldOverrideUrlLoading: (c, action) =>
                        gateway.navigation(widget.addon, action),
                    onWebViewCreated: (c) {
                      _controller = c;
                      _timer ??= Timer.periodic(
                        const Duration(seconds: 1),
                        (_) => _check(),
                      );
                    },
                    onProgressChanged: (c, value) {
                      if (mounted) setState(() => _progress = value / 100);
                    },
                    onLoadStop: (c, url) => _check(),
                    onReceivedError: (c, request, error) {
                      if (request.isForMainFrame == true && mounted) {
                        setState(
                          () => _error =
                              'Could not load sign-in. Check your connection and reload.',
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Home observes the live account service; no playlist transfer or manual links.
class NewConnectedMusicFeed extends ConsumerStatefulWidget {
  const NewConnectedMusicFeed({super.key});
  @override
  ConsumerState<NewConnectedMusicFeed> createState() =>
      _NewConnectedMusicFeedState();
}

class _NewConnectedMusicFeedState extends ConsumerState<NewConnectedMusicFeed>
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
      unawaited(ref.read(connectedMusicProvider).refreshAll());
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(connectedMusicProvider);
    void accounts() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NewConnectedAccountsScreen()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: InkWell(
            onTap: accounts,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: NewExperienceTokens.accentViolet.withValues(
                    alpha: .25,
                  ),
                ),
                gradient: LinearGradient(
                  colors: [
                    NewExperienceTokens.accentViolet.withValues(alpha: .13),
                    NewExperienceTokens.cardSurface,
                  ],
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.hub_rounded,
                    color: NewExperienceTokens.accentViolet,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.hasConnections
                              ? 'Your connected music'
                              : 'Bring your listening world together',
                          style: NewExperienceTokens.sectionTitle(fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          service.hasConnections
                              ? 'Live playlists from your accounts'
                              : 'Connect YouTube Music or Spotify. Your playlists appear here.',
                          style: NewExperienceTokens.bodySmall(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
        ),
        for (final addon in accountAddons)
          if (service.account(addon.id).linked) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'From ${addon.name}',
                      style: NewExperienceTokens.sectionTitle(),
                    ),
                  ),
                  if (service.account(addon.id).status ==
                      ConnectionStatus.refreshing)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  IconButton(
                    onPressed: accounts,
                    tooltip: 'Manage connection',
                    icon: Icon(
                      Icons.tune_rounded,
                      color: Color(addon.color),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            if (service.account(addon.id).message != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Text(
                  service.account(addon.id).message!,
                  style: NewExperienceTokens.bodySmall(),
                ),
              ),
            if (service.account(addon.id).playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Text(
                  service.account(addon.id).status ==
                          ConnectionStatus.refreshing
                      ? 'Finding your playlists…'
                      : 'Saved playlists from this account will appear here.',
                  style: NewExperienceTokens.bodySmall(),
                ),
              ),
            if (service.account(addon.id).playlists.isNotEmpty)
              SizedBox(
                height:
                    164 +
                    MediaQuery.textScalerOf(context).scale(14) * 2.7 +
                    MediaQuery.textScalerOf(context).scale(12.5) * 1.5 +
                    24,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: service.account(addon.id).playlists.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final playlist = service.account(addon.id).playlists[index];
                    return NewCard(
                      title: playlist.title,
                      subtitle: playlist.owner.isEmpty
                          ? playlist.section
                          : playlist.owner,
                      badgeText: 'LIVE',
                      imageUrl: playlist.artwork,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              NewConnectedPlaylistScreen(playlist: playlist),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
      ],
    );
  }
}

class NewConnectedPlaylistScreen extends ConsumerWidget {
  final RemotePlaylist playlist;
  const NewConnectedPlaylistScreen({super.key, required this.playlist});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(connectedMusicProvider);
    final page = ref.watch(remotePlaylistProvider(playlist));
    final snapshot = page.valueOrNull;
    final tracks = snapshot?.tracks ?? [];
    final loading =
        !page.hasError && snapshot?.complete != true && snapshot?.error == null;
    final failed = page.hasError || snapshot?.error != null;
    return Scaffold(
      backgroundColor: NewExperienceTokens.obsidianBackground,
      appBar: AppBar(
        title: Text(
          playlist.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      NewArtworkImage(
                        imageUrl: playlist.artwork,
                        width: 180,
                        height: 180,
                        fallbackTitle: playlist.title,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        playlist.title,
                        textAlign: TextAlign.center,
                        style: NewExperienceTokens.displayHero(fontSize: 28),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${playlist.owner.isEmpty ? playlist.section : playlist.owner} · ${tracks.length} tracks${loading ? ' · Loading more' : ''}',
                        textAlign: TextAlign.center,
                        style: NewExperienceTokens.bodySmall(),
                      ),
                      const SizedBox(height: 16),
                      if (playlist.videoId == null) FilledButton.icon(
                        onPressed: tracks.isEmpty
                            ? null
                            : () => ref
                                  .read(connectedPlaybackProvider)
                                  .play(playlist, 0),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play'),
                      ),
                      if (playlist.videoId == null) CollectionDownloadButton(collectionId: playlist.key, title: playlist.title,
                        loadSongs: () => loadRemoteCollection(service.playlist(playlist))),
                      if (playlist.videoId != null && snapshot != null)
                        NewMixChaptersPanel(playlist: playlist, snapshot: snapshot),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: LinearProgressIndicator(),
                        ),
                      if (failed) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Could not load the complete playlist. You can retry or reconnect your account.',
                          textAlign: TextAlign.center,
                          style: NewExperienceTokens.bodySmall(),
                        ),
                        Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => ref.invalidate(
                                remotePlaylistProvider(playlist),
                              ),
                              child: const Text('Retry'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const NewConnectedAccountsScreen(),
                                ),
                              ),
                              child: const Text('Connection settings'),
                            ),
                          ],
                        ),
                      ],
                      if (!loading && !failed && tracks.isEmpty)
                        Text(
                          'This playlist has no available tracks.',
                          style: NewExperienceTokens.bodyMedium(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: playlist.videoId != null ? 0 : tracks.length,
            itemBuilder: (context, index) {
              final entry = tracks[index];
              return ListTile(
                key: ValueKey(entry.entryId),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 4,
                ),
                leading: NewArtworkImage(
                  imageUrl: entry.song.coverArt,
                  width: 48,
                  height: 48,
                  fallbackTitle: entry.song.title,
                  borderRadius: BorderRadius.circular(8),
                ),
                title: Text(
                  entry.song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NewExperienceTokens.bodyMedium(),
                ),
                subtitle: Text(
                  entry.song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NewExperienceTokens.bodySmall(),
                ),
                trailing: CollectionDownloadButton(collectionId: 'track:${entry.song.id}', title: entry.song.title, songs: [entry.song], iconOnly: true),
                onTap: () =>
                    ref.read(connectedPlaybackProvider).play(playlist, index),
              );
            },
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: ContentViewportInsets.bottom(context, ref)),
          ),
        ],
      ),
    );
  }
}
