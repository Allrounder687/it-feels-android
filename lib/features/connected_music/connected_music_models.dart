import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/models/mix_chapter.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  refreshing,
  reconnect,
  offline,
}

/// The app owns account orchestration; installed addons own service knowledge.
class AccountAddon {
  final String id, name, asset, origin, loginUrl, libraryUrl;
  final List<String> navigationDomains, cookieDomains;
  final int color;
  const AccountAddon({
    required this.id,
    required this.name,
    required this.asset,
    required this.origin,
    required this.loginUrl,
    required this.libraryUrl,
    required this.navigationDomains,
    required this.cookieDomains,
    required this.color,
  });

  bool allowsNavigation(Uri uri) =>
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      navigationDomains.any((d) => uri.host == d || uri.host.endsWith('.$d'));
  bool ownsPage(Uri uri) =>
      uri.scheme == 'https' && uri.host == Uri.parse(origin).host;
}

// These are addon installation descriptors, not provider API implementations.
const accountAddons = [
  AccountAddon(
    id: 'youtube_music',
    name: 'YouTube Music',
    asset: 'assets/account_addons/youtube_music.js',
    origin: 'https://music.youtube.com',
    loginUrl: 'https://music.youtube.com/library/playlists',
    libraryUrl: 'https://music.youtube.com/library/playlists',
    navigationDomains: [
      'youtube.com',
      'google.com',
      'google.co.in',
      'gstatic.com',
      'googleusercontent.com',
    ],
    cookieDomains: ['music.youtube.com', 'youtube.com'],
    color: 0xFFFF4268,
  ),
  AccountAddon(
    id: 'spotify',
    name: 'Spotify',
    asset: 'assets/account_addons/spotify.js',
    origin: 'https://open.spotify.com',
    loginUrl: 'https://open.spotify.com/collection/playlists',
    libraryUrl: 'https://open.spotify.com/collection/playlists',
    navigationDomains: [
      'spotify.com',
      'google.com',
      'apple.com',
      'facebook.com',
    ],
    cookieDomains: ['open.spotify.com', 'spotify.com', 'accounts.spotify.com'],
    color: 0xFF1ED760,
  ),
];

class RemotePlaylist {
  final bool requiresAccount;
  final String? videoId;
  final String providerId, id, title, owner, artwork, url, section;
  final int? trackCount;
  const RemotePlaylist({
    required this.providerId,
    required this.id,
    required this.title,
    this.owner = '',
    this.artwork = '',
    required this.url,
    this.section = 'Your playlists',
    this.trackCount,
    this.requiresAccount = true,
    this.videoId,
  });
  String get key => '$providerId:$id';
  @override
  bool operator ==(Object other) => other is RemotePlaylist && other.key == key;
  @override
  int get hashCode => key.hashCode;
  factory RemotePlaylist.fromJson(String provider, Map<String, dynamic> j) {
    final url = Uri.tryParse(j['url']?.toString() ?? '');
    final addon = accountAddons.where((a) => a.id == provider).firstOrNull;
    if (addon == null ||
        url == null ||
        !addon.ownsPage(url) ||
        (j['id']?.toString().isEmpty ?? true) ||
        (j['title']?.toString().trim().isEmpty ?? true)) {
      throw const FormatException('Invalid remote playlist');
    }
    return RemotePlaylist(
      providerId: provider,
      id: j['id'].toString(),
      title: j['title'].toString(),
      owner: j['owner']?.toString() ?? '',
      artwork: _image(j['artwork']),
      url: url.toString(),
      section: j['section']?.toString() ?? 'Your playlists',
      trackCount: j['trackCount'] is num
          ? (j['trackCount'] as num).toInt()
          : null,
      requiresAccount: j['requiresAccount'] != false,
      videoId: j['videoId']?.toString(),
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'owner': owner,
    'artwork': artwork,
    'url': url,
    'section': section,
    'trackCount': trackCount,
    'requiresAccount': requiresAccount,
    'videoId': videoId,
  };
}

String _image(Object? value) {
  final u = Uri.tryParse(value?.toString() ?? '');
  return u != null &&
          u.scheme == 'https' &&
          u.host.isNotEmpty &&
          u.userInfo.isEmpty
      ? u.toString()
      : '';
}

class RemoteTrack {
  final String entryId;
  final Song song;
  const RemoteTrack(this.entryId, this.song);
  factory RemoteTrack.fromJson(String provider, Map<String, dynamic> j) {
    final id = j['id']?.toString() ?? '';
    final title = j['title']?.toString().trim() ?? '';
    if (id.isEmpty || title.isEmpty) {
      throw const FormatException('Invalid remote track');
    }
    return RemoteTrack(
      j['entryId']?.toString() ?? id,
      Song(
        id: '${provider == 'youtube_music' ? 'youtube' : provider}:$id',
        saavnId: '',
        addedAt: DateTime.now(),
        title: title,
        artist: j['artist']?.toString() ?? '',
        album: j['album']?.toString() ?? '',
        duration: (j['duration'] is num ? (j['duration'] as num).toInt() : 0)
            .clamp(0, 86400),
        coverArt: _image(j['artwork']),
      ),
    );
  }
}

class AccountSnapshot {
  final List<MixChapter> chapters;
  final bool authenticated, complete;
  final String accountName;
  final List<RemotePlaylist> playlists;
  final List<RemoteTrack> tracks;
  final String? error;
  const AccountSnapshot({
    this.authenticated = false,
    this.complete = false,
    this.accountName = '',
    this.playlists = const [],
    this.tracks = const [],
    this.error,
    this.chapters = const [],
  });
  factory AccountSnapshot.fromJson(String provider, Map<String, dynamic> j) {
    final playlists = <RemotePlaylist>[];
    final tracks = <RemoteTrack>[];
    for (final item
        in (j['playlists'] is List ? j['playlists'] as List : const [])) {
      if (item is! Map) continue;
      try {
        playlists.add(
          RemotePlaylist.fromJson(provider, Map<String, dynamic>.from(item)),
        );
      } on FormatException {
        /* A malformed entry must not poison the whole library. */
      }
    }
    for (final item in (j['tracks'] is List ? j['tracks'] as List : const [])) {
      if (item is! Map) continue;
      try {
        tracks.add(
          RemoteTrack.fromJson(provider, Map<String, dynamic>.from(item)),
        );
      } on FormatException {
        /* Deleted/unavailable tracks are omitted by the addon. */
      }
    }
    final chapters = <MixChapter>[];
    for (final item
        in j['chapters'] is List ? j['chapters'] as List : const []) {
      if (item is! Map) continue;
      try {
        chapters.add(MixChapter.fromJson(Map<String, dynamic>.from(item)));
      } on FormatException {
        /* Ignore invalid chapter markers. */
      }
    }
    return AccountSnapshot(
      authenticated: j['authenticated'] == true,
      complete: j['complete'] == true,
      accountName: j['accountName']?.toString() ?? '',
      playlists: playlists,
      tracks: tracks,
      error: j['error']?.toString(),
      chapters: chapters,
    );
  }
}

class AccountConnection {
  final ConnectionStatus status;
  final String name;
  final List<RemotePlaylist> playlists;
  final DateTime? updatedAt;
  final String? message;
  const AccountConnection({
    this.status = ConnectionStatus.disconnected,
    this.name = '',
    this.playlists = const [],
    this.updatedAt,
    this.message,
  });
  bool get linked =>
      status != ConnectionStatus.disconnected &&
      status != ConnectionStatus.connecting;
}

class AccountAccessException implements Exception {
  final bool needsLogin;
  const AccountAccessException({this.needsLogin = false});
}
