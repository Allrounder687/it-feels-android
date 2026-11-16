import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connected_music_models.dart';
import 'connected_music_service.dart';

class PreferencesAccountStore
    implements AccountStore, AccountPlaylistCacheStore {
  static const _playlistPrefix = 'connected_music.v1.playlist.';
  final Directory? playlistDirectory;
  Future<Directory>? _directory;
  PreferencesAccountStore({this.playlistDirectory});

  Future<File> _playlistFile(String key) async {
    final directory = await (_directory ??= () async {
      final root =
          playlistDirectory ??
          Directory(
            '${(await getApplicationSupportDirectory()).path}/connected_playlist_cache',
          );
      await root.create(recursive: true);
      return root;
    }());
    final provider = key
        .substring(_playlistPrefix.length)
        .split(':')
        .first
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return File(
      '${directory.path}/${provider}_${sha256.convert(utf8.encode(key))}.json',
    );
  }

  @override
  Future<String?> read(String key) async {
    if (!key.startsWith(_playlistPrefix)) {
      return (await SharedPreferences.getInstance()).getString(key);
    }
    final file = await _playlistFile(key);
    if (await file.exists()) return compute(_readPlaylistFile, file.path);
    final legacy = (await SharedPreferences.getInstance()).getString(key);
    if (legacy != null) await write(key, legacy);
    return legacy;
  }

  @override
  Future<void> write(String key, String value) async {
    if (key.startsWith(_playlistPrefix)) {
      final file = await _playlistFile(key);
      await compute(_writePlaylistFile, (file.path, value));
      final preferences = await SharedPreferences.getInstance();
      if (preferences.containsKey(key)) await preferences.remove(key);
      await _prune(file);
      return;
    }
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw const AccountAccessException();
    }
  }

  @override
  Future<void> delete(String key) async {
    if (key.startsWith(_playlistPrefix)) {
      final file = await _playlistFile(key);
      if (await file.exists()) await file.delete();
    }
    await (await SharedPreferences.getInstance()).remove(key);
  }

  Future<void> _prune(File protected) async {
    try {
      if ((await protected.stat()).size > 32 * 1024 * 1024) {
        await protected.delete();
        return;
      }
      final files = <(File, FileStat)>[];
      await for (final entry in protected.parent.list()) {
        if (entry is File && entry.path.endsWith('.json')) {
          files.add((entry, await entry.stat()));
        }
      }
      files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
      var count = files.length,
          bytes = files.fold<int>(0, (sum, f) => sum + f.$2.size);
      for (final (file, stat) in files) {
        if (count <= 32 && bytes <= 32 * 1024 * 1024) break;
        if (file.path == protected.path) continue;
        await file.delete();
        count--;
        bytes -= stat.size;
      }
    } catch (_) {
      /* Cache pruning must not interrupt an active playlist. */
    }
  }

  @override
  Future<void> clearPlaylistCache(String provider) async {
    final file = await _playlistFile('$_playlistPrefix$provider:_clear');
    final safeProvider = provider.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    await for (final entry in file.parent.list()) {
      if (entry is File &&
          entry.uri.pathSegments.last.startsWith('${safeProvider}_')) {
        await entry.delete();
      }
    }
    final preferences = await SharedPreferences.getInstance();
    for (final key in preferences.getKeys().where(
      (k) => k.startsWith('$_playlistPrefix$provider:'),
    )) {
      await preferences.remove(key);
    }
  }
}

Future<String> _readPlaylistFile(String path) => File(path).readAsString();
Future<void> _writePlaylistFile((String, String) input) async {
  final temporary = File('${input.$1}.tmp');
  try {
    await temporary.writeAsString(input.$2, flush: true);
    await temporary.rename(input.$1);
  } finally {
    if (await temporary.exists()) await temporary.delete();
  }
}

/// Runs only user-selected account addons, in each service's own browser origin.
/// No passwords, API keys, token extraction or service endpoints live in this host.
class AccountBrowserGateway implements AccountGateway, PublicPlaylistGateway {
  final FlutterSecureStorage secrets;
  final Map<String, String> _sources = {};
  final Map<String, Future<WebViewEnvironment?>> _environments = {};
  final Map<String, Set<HeadlessInAppWebView>> _readers = {};
  final Map<String, int> _generations = {};
  final Map<String, Future<void>> _sessionTasks = {};
  bool _disposed = false;
  AccountBrowserGateway({
    this.secrets = const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  });
  int _activeReads = 0;
  final Queue<Completer<void>> _waitingReads = Queue();
  Future<void> _acquire({bool foreground = false}) async {
    if (_disposed) throw const AccountAccessException();
    if (_activeReads < 1) {
      _activeReads++;
      return;
    }
    final waiter = Completer<void>();
    if (foreground) {
      _waitingReads.addFirst(waiter);
    } else {
      _waitingReads.add(waiter);
    }
    await waiter.future;
  }

  void _release() {
    _activeReads--;
    if (_waitingReads.isNotEmpty && !_disposed) {
      _activeReads++;
      _waitingReads.removeFirst().complete();
    }
  }

  Future<void> _session(String id, Future<void> Function() operation) {
    final next = (_sessionTasks[id] ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) => operation());
    _sessionTasks[id] = next;
    return next;
  }

  static bool get supported =>
      !kIsWeb &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      }.contains(defaultTargetPlatform);

  @override
  Future<void> install(AccountAddon addon) async {
    if (!supported) throw const AccountAccessException();
    if (_sources.containsKey(addon.id)) return;
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/account_addons/${addon.id}.js');
    // Bundled, versioned reader is installed when the user chooses Connect.
    // Keep it separate from URL-only audio addons and their global JS namespace.
    final source = await rootBundle.loadString(addon.asset);
    await file.parent.create(recursive: true);
    await file.writeAsString(source, flush: true);
    _sources[addon.id] = source;
  }

  Future<WebViewEnvironment?> environment(AccountAddon addon) =>
      _environments.putIfAbsent(addon.id, () async {
        if (defaultTargetPlatform != TargetPlatform.windows) return null;
        final directory = await getApplicationSupportDirectory();
        final folder = Directory(
          '${directory.path}/account_browsers/${addon.id}',
        );
        await folder.create(recursive: true);
        return WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(userDataFolder: folder.path),
        );
      });

  Future<UnmodifiableListView<UserScript>> scripts(AccountAddon addon) async {
    await install(addon);
    return UnmodifiableListView([
      UserScript(
        source: _sources[addon.id]!,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: true,
      ),
    ]);
  }

  InAppWebViewSettings get settings => InAppWebViewSettings(
    javaScriptEnabled: true,
    domStorageEnabled: true,
    thirdPartyCookiesEnabled: true,
    useShouldOverrideUrlLoading: true,
    mediaPlaybackRequiresUserGesture: true,
    supportMultipleWindows: false,
    isInspectable: false,
  );

  Future<NavigationActionPolicy> navigation(
    AccountAddon addon,
    NavigationAction action,
  ) async {
    if (action.isForMainFrame == false) {
      // Service-owned sign-in pages may embed third-party challenge frames.
      // Addon scripts are main-frame-only and never run in these frames.
      return NavigationActionPolicy.ALLOW;
    }
    final uri = action.request.url;
    // Subresources are not navigations; never expose addon JS on a third-party main page.
    return uri != null && addon.allowsNavigation(uri)
        ? NavigationActionPolicy.ALLOW
        : NavigationActionPolicy.CANCEL;
  }

  Future<AccountSnapshot?> snapshot(
    AccountAddon addon,
    InAppWebViewController controller, {
    bool incremental = false,
  }) async {
    final url = await controller.getUrl();
    if (url == null || !addon.ownsPage(url)) return null;
    final raw = await controller.evaluateJavascript(
      source: incremental
          ? '''
        (() => {
          if (!window.itFeelsAccount) return null;
          const state = window.itFeelsAccount.snapshot();
          const revision = [state.authenticated, state.complete, state.error,
            state.accountName, state.playlists.length, state.tracks.length,
            (state.chapters || []).length].join(':');
          if (window.__itFeelsRevision === revision) return null;
          window.__itFeelsRevision = revision;
          const offset = window.__itFeelsTrackOffset || 0;
          window.__itFeelsTrackOffset = state.tracks.length;
          return JSON.stringify(Object.assign({}, state, {tracks: state.tracks.slice(offset)}));
        })()
      '''
          : 'window.itFeelsAccount ? JSON.stringify(window.itFeelsAccount.snapshot()) : null',
    );
    if (raw is! String || raw.length > 16 * 1024 * 1024) return null;
    return decodeAccountSnapshot(addon.id, raw);
  }

  Future<void> remember(AccountAddon addon) {
    final generation = _generations[addon.id] ?? 0;
    return _session(addon.id, () async {
      if (_disposed || (_generations[addon.id] ?? 0) != generation) return;
      final manager = CookieManager.instance(
        webViewEnvironment: await environment(addon),
      );
      final cookies = <Map<String, dynamic>>[];
      for (final host in addon.cookieDomains) {
        for (final c in await manager.getCookies(
          url: WebUri('https://$host'),
        )) {
          // Persist only the service's cookie jar, never Google/Facebook login cookies.
          cookies.add({
            'name': c.name,
            'value': c.value,
            'domain': c.domain ?? host,
            'path': c.path ?? '/',
            'expires': c.expiresDate,
            'secure': c.isSecure ?? true,
            'httpOnly': c.isHttpOnly ?? false,
          });
        }
      }
      await secrets.write(
        key: 'account_session.${addon.id}',
        value: jsonEncode(cookies),
      );
    });
  }

  Future<void> restore(AccountAddon addon) {
    final generation = _generations[addon.id] ?? 0;
    return _session(addon.id, () async {
      if (_disposed || (_generations[addon.id] ?? 0) != generation) return;
      final raw = await secrets.read(key: 'account_session.${addon.id}');
      if (raw == null) return;
      final manager = CookieManager.instance(
        webViewEnvironment: await environment(addon),
      );
      for (final item in jsonDecode(raw) as List) {
        final domain = (item['domain'] as String).replaceFirst(
          RegExp(r'^\.'),
          '',
        );
        if (!addon.cookieDomains.any(
          (h) => h == domain || h.endsWith('.$domain'),
        )) {
          continue;
        }
        final expires = (item['expires'] as num?)?.toInt();
        if (expires != null &&
            expires <= DateTime.now().millisecondsSinceEpoch) {
          continue;
        }
        await manager.setCookie(
          url: WebUri('https://$domain'),
          name: item['name'] as String,
          value: item['value'] as String,
          domain: item['domain'] as String,
          path: item['path'] as String,
          expiresDate: expires,
          isSecure: item['secure'] as bool,
          isHttpOnly: item['httpOnly'] as bool,
        );
      }
    });
  }

  @override
  Stream<AccountSnapshot> read(
    AccountAddon addon, {
    RemotePlaylist? playlist,
    bool discovery = false,
    String? audioId,
  }) => Stream.multi((sink) {
    var canceled = false;
    sink.onCancel = () {
      canceled = true;
    };
    final generation = _generations[addon.id] ?? 0;
    unawaited(() async {
      var acquired = false;
      try {
        await _acquire(foreground: playlist != null || audioId != null);
        acquired = true;
        if (!_disposed &&
            !canceled &&
            (_generations[addon.id] ?? 0) == generation) {
          await for (final page in _read(
            addon,
            playlist: playlist,
            discovery: discovery,
            audioId: audioId,
            isCanceled: () => canceled,
          )) {
            if (!canceled) sink.add(page);
          }
        }
      } catch (error, stack) {
        if (!canceled) sink.addError(error, stack);
      } finally {
        if (acquired) _release();
        if (!canceled) sink.close();
      }
    }());
  });

  Stream<AccountSnapshot> _read(
    AccountAddon addon, {
    RemotePlaylist? playlist,
    bool discovery = false,
    String? audioId,
    required bool Function() isCanceled,
  }) async* {
    if (_disposed || !supported) throw const AccountAccessException();
    final generation = _generations[addon.id] ?? 0;
    await install(addon);
    await restore(addon);
    if (_disposed ||
        isCanceled() ||
        (_generations[addon.id] ?? 0) != generation) {
      return;
    }
    final options = jsonEncode({
      'mode': audioId != null
          ? 'audio'
          : discovery
          ? 'discover'
          : playlist?.videoId != null
          ? 'mix'
          : playlist == null
          ? 'feed'
          : 'playlist',
      'id': playlist?.id,
      'videoId': audioId ?? playlist?.videoId,
      'allowAnonymous': playlist?.requiresAccount == false,
    });
    var started = false;
    final browser = HeadlessInAppWebView(
      initialSize: addon.readerUrl != null
          ? const Size(1, 1)
          : const Size(900, 700),
      webViewEnvironment: await environment(addon),
      initialUrlRequest: URLRequest(
        url: WebUri(
          addon.readerUrl ??
              playlist?.url ??
              (discovery ? addon.origin : addon.libraryUrl),
        ),
      ),
      initialSettings: settings..blockNetworkImage = true,
      initialUserScripts: addon.readerUrl == null ? await scripts(addon) : null,
      shouldOverrideUrlLoading: (c, action) => navigation(addon, action),
      onLoadStop: (c, url) async {
        if (started || url == null || !addon.ownsPage(url)) return;
        started = true;
        if (addon.readerUrl != null) {
          await c.evaluateJavascript(source: _sources[addon.id]!);
        }
        await c.evaluateJavascript(
          source:
              'window.itFeelsAccount && window.itFeelsAccount.start($options)',
        );
      },
    );
    (_readers[addon.id] ??= {}).add(browser);
    try {
      await browser.run();
      final deadline = DateTime.now().add(
        audioId != null
            ? const Duration(seconds: 12)
            : const Duration(minutes: 2),
      );
      while (!_disposed &&
          !isCanceled() &&
          (_generations[addon.id] ?? 0) == generation &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 1000));
        final controller = browser.webViewController;
        if (controller == null) continue;
        final currentUrl = await controller.getUrl();
        if (started &&
            currentUrl != null &&
            addon.allowsNavigation(currentUrl) &&
            !addon.ownsPage(currentUrl)) {
          final path = currentUrl.path.toLowerCase();
          final host = currentUrl.host.toLowerCase();
          if (host.contains('accounts.') ||
              path.contains('signin') ||
              path.contains('login') ||
              path.contains('servicelogin')) {
            throw const AccountAccessException(needsLogin: true);
          }
        }
        final page = await snapshot(addon, controller, incremental: true);
        if (page == null) continue;
        yield page;
        if (page.error != null) {
          if (page.error == 'login_required') {
            throw const AccountAccessException(needsLogin: true);
          }
          return;
        }
        if (page.complete) {
          if (page.authenticated && !discovery && audioId == null) {
            await remember(addon);
          }
          return;
        }
      }
      if (!_disposed &&
          !isCanceled() &&
          (_generations[addon.id] ?? 0) == generation) {
        throw const AccountAccessException();
      }
    } finally {
      if (_readers[addon.id]?.remove(browser) == true) await browser.dispose();
    }
  }

  @override
  Stream<AccountSnapshot> discover(AccountAddon addon) =>
      read(addon, discovery: true);

  @override
  Future<void> disconnect(AccountAddon addon) async {
    _generations[addon.id] = (_generations[addon.id] ?? 0) + 1;
    for (final browser
        in _readers[addon.id]?.toList() ?? <HeadlessInAppWebView>[]) {
      if (_readers[addon.id]?.remove(browser) == true) await browser.dispose();
    }
    await _session(addon.id, () async {
      await secrets.delete(key: 'account_session.${addon.id}');
      final manager = CookieManager.instance(
        webViewEnvironment: await environment(addon),
      );
      for (final host in addon.cookieDomains) {
        for (final cookie in await manager.getCookies(
          url: WebUri('https://$host'),
        )) {
          await manager.deleteCookie(
            url: WebUri('https://$host'),
            name: cookie.name,
            domain: cookie.domain,
            path: cookie.path ?? '/',
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    while (_waitingReads.isNotEmpty) {
      _waitingReads.removeFirst().completeError(const AccountAccessException());
    }
    for (final readers in _readers.values) {
      for (final browser in readers.toList()) {
        if (readers.remove(browser)) unawaited(browser.dispose());
      }
    }
  }
}
