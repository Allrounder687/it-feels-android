/* IT Feels account addon v1. Metadata only; never decrypts or downloads Spotify audio.
 * Original browser-session reader, inspired by Spotube's split provider architecture.
 * The service's own web player supplies its authentication; no embedded client secret.
 */
(function () {
  'use strict';
  if (location.origin !== 'https://open.spotify.com') return;
  var state = { authenticated: false, accountName: '', playlists: [], tracks: [], complete: false };
  var accessToken = '', checkedToken = '', verifying = false, running = false, responses = [], entries = new Map(), loadedPositions = new Set(), total = null;
  var originalFetch = window.fetch;
  function pause(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }
  function captureHeaders(headers) {
    try {
      var auth = new Headers(headers || {}).get('authorization');
      if (auth && auth.indexOf('Bearer ') === 0) accessToken = auth.slice(7);
    } catch (_) { /* Not every request has headers. */ }
  }
  // Observe only Spotify's own requests. Never record credentials in a snapshot or log.
  window.fetch = function (resource, init) {
    var url = typeof resource === 'string' ? resource : resource.url || '';
    var host;
    try { host = new URL(url, location.href).hostname; } catch (_) { host = ''; }
    var service = host === 'api.spotify.com' || host === 'api-partner.spotify.com' || host === 'open.spotify.com';
    if (service) { captureHeaders(init && init.headers); captureHeaders(resource && resource.headers); }
    var result = originalFetch.apply(this, arguments);
    if (service && (url.indexOf('/api/token') >= 0 || url.indexOf('/pathfinder/') >= 0 || url.indexOf('/get_access_token') >= 0)) {
      result.then(function (response) {
        if (!response.ok) return;
        response.clone().json().then(function (body) {
          if (body.accessToken && !body.isAnonymous) accessToken = body.accessToken;
          if (body.data && responses.length < 40) {
            var request = {};
            try { request = init && init.body ? JSON.parse(init.body) : { variables: JSON.parse(new URL(url, location.href).searchParams.get('variables') || '{}') }; } catch (_) { /* Non-JSON request. */ }
            responses.push({ body: body, offset: request.variables && request.variables.offset || 0 });
          }
        }).catch(function () {});
      }).catch(function () {});
    }
    return result;
  };
  var tokenFetching = false;
  async function fetchTokenIfMissing() {
    if (accessToken || tokenFetching) return accessToken;
    tokenFetching = true;
    try {
      var res = await originalFetch('https://open.spotify.com/get_access_token?reason=transport&productType=web_player', { credentials: 'include' });
      if (res.ok) {
        var body = await res.json();
        if (body.accessToken && !body.isAnonymous) accessToken = body.accessToken;
      }
    } catch (_) {} finally {
      tokenFetching = false;
    }
    return accessToken;
  }
  function tokenFromPage() {
    try {
      var session = document.querySelector('script#session');
      var data = session && JSON.parse(session.textContent);
      if (!accessToken && data && data.accessToken && !data.isAnonymous) accessToken = data.accessToken;
    } catch (_) { /* Web builds may omit this script. */ }
    if (!accessToken) fetchTokenIfMissing();
    return accessToken;
  }
  async function api(path) {
    var response = await originalFetch('https://api.spotify.com/v1/' + path,
      { headers: { Authorization: 'Bearer ' + accessToken } });
    if (response.status === 401) throw new Error('login_required');
    if (!response.ok) throw new Error(response.status === 429 ? 'rate_limited' : 'restricted');
    return response.json();
  }
  function artwork(images) { return images && images.length ? images[0].url || '' : ''; }
  function track(t, index) {
    if (!t || t.is_local || t.type === 'episode' || !t.id || !t.name || t.is_playable === false) return null;
    return { entryId: String(index), id: t.id, title: t.name,
      artist: (t.artists || []).map(function (a) { return a.name; }).join(', '),
      album: t.album && t.album.name || '', artwork: artwork(t.album && t.album.images), duration: Math.round((t.duration_ms || 0) / 1000) };
  }
  function browserTracks() {
    // Consume the official page's playlist responses, including virtualized pages.
    responses.splice(0).forEach(function (response) {
      var playlist = response.body.data.playlistV2 || response.body.data.playlist;
      var content = playlist && playlist.content;
      if (!content || !Array.isArray(content.items)) return;
      if (Number.isFinite(content.totalCount)) total = content.totalCount;
      var pageOffset = content.pagingInfo && Number.isFinite(content.pagingInfo.offset) ? content.pagingInfo.offset : response.offset;
      content.items.forEach(function (item, index) {
        loadedPositions.add(pageOffset + index);
        var t = item.itemV2 && item.itemV2.data || item.item && item.item.data;
        if (!t || t.__typename !== 'Track' || !t.uri) return;
        var position = pageOffset + index;
        entries.set(position, { entryId: String(position), id: t.uri.split(':').pop(), title: t.name,
          artist: ((t.artists && t.artists.items) || []).map(function (a) { return a.profile && a.profile.name || ''; }).join(', '),
          album: t.albumOfTrack && t.albumOfTrack.name || '',
          artwork: artwork(t.albumOfTrack && t.albumOfTrack.coverArt && t.albumOfTrack.coverArt.sources),
          duration: Math.round((t.trackDuration && t.trackDuration.totalMilliseconds || t.duration && t.duration.totalMilliseconds || 0) / 1000) });
      });
    });
    var grid = document.querySelector('[data-testid="playlist-tracklist"][aria-rowcount], [data-testid="playlist-tracklist"] [role="grid"][aria-rowcount]');
    var rowCount = grid && Number(grid.getAttribute('aria-rowcount'));
    if (total === null && Number.isFinite(rowCount) && rowCount > 0) total = rowCount - 1;
    var rows = document.querySelectorAll('[data-testid="playlist-tracklist"] [data-testid="tracklist-row"]');
    rows.forEach(function (row) {
      var a = row.querySelector('a[href*="/track/"]');
      var index = Number(row.getAttribute('aria-rowindex') || row.closest('[aria-rowindex]') && row.closest('[aria-rowindex]').getAttribute('aria-rowindex'));
      var number = row.querySelector('[data-testid="tracklist-row"] span') || row.querySelector('[role="gridcell"] span');
      if (!index && number) index = Number(number.textContent) + 1;
      if (!Number.isFinite(index) || index < 2) return;
      loadedPositions.add(index - 2);
      if (!a) return;
      var id = new URL(a.href).pathname.split('/').pop();
      var artists = Array.from(row.querySelectorAll('a[href*="/artist/"]')).map(function (e) { return e.textContent.trim(); });
      var album = row.querySelector('a[href*="/album/"]'), img = row.querySelector('img');
      // DOM indices include a header row. Prefer network rows; DOM is a fallback only.
      if (!entries.has(index - 2)) entries.set(index - 2, { entryId: String(index - 2), id: id,
        title: a.textContent.trim(), artist: artists.join(', '), album: album && album.textContent || '',
        artwork: img && img.src || '', duration: 0 });
    });
    state.tracks = Array.from(entries.entries()).sort(function (a, b) { return a[0] - b[0]; }).map(function (p) { return p[1]; });
  }
  async function playlist(id) {
    // Official endpoint where permitted. Followed playlists fall back to their web view.
    try {
      for (var offset = 0; offset < 10000;) {
        var page = await api('playlists/' + encodeURIComponent(id) + '/items?limit=50&offset=' + offset);
        if (!Array.isArray(page.items)) throw new Error('restricted');
        page.items.forEach(function (item, i) { var t = track(item.item || item.track, offset + i); if (t) entries.set(offset + i, t); });
        offset += page.items.length;
        state.tracks = Array.from(entries.values());
        if (!page.next) return;
        if (!page.items.length) throw new Error('incomplete');
      }
      throw new Error('incomplete');
    } catch (error) {
      if (error.message !== 'restricted') throw error;
      entries.clear();
    }
    var stable = 0, previous = 0;
    for (var step = 0; step < 160; step++) {
      browserTracks();
      if (total !== null && loadedPositions.size >= total) return;
      stable = entries.size === previous ? stable + 1 : 0; previous = entries.size;
      var scroll = document.querySelector('main [data-overlayscrollbars-viewport]') || document.querySelector('[data-testid="main-view"] [data-overlayscrollbars-viewport]') || document.scrollingElement;
      if (scroll) scroll.scrollTop += Math.max(500, scroll.clientHeight * 0.8);
      if (stable > 15 && total === 0) return;
      await pause(450);
    }
    throw new Error('incomplete');
  }
  window.itFeelsAccount = {
    snapshot: function () {
      tokenFromPage();
      if (!accessToken) fetchTokenIfMissing();
      // A login cookie alone is not proof of a usable account session.
      if (accessToken && accessToken !== checkedToken && !verifying) {
        verifying = true;
        checkedToken = accessToken;
        api('me').then(function (p) {
          state.authenticated = true;
          state.accountName = p.display_name || p.id || '';
        }).catch(function () { state.authenticated = false; }).finally(function () { verifying = false; });
      }
      return state;
    },
    start: function (input) {
      if (running) return; running = true;
      (async function () {
        for (var i = 0; i < 60 && !tokenFromPage(); i++) {
          await fetchTokenIfMissing();
          if (accessToken) break;
          await pause(300);
        }
        if (!accessToken) throw new Error('login_required');
        var profile = await api('me');
        state.authenticated = true; state.accountName = profile.display_name || profile.id || '';
        if (input.mode === 'playlist') {
          if (!/^[A-Za-z0-9]+$/.test(input.id || '')) throw new Error('invalid_playlist');
          await playlist(input.id);
        } else {
          for (var offset = 0; offset < 3000;) {
            var page = await api('me/playlists?limit=50&offset=' + offset);
            if (!Array.isArray(page.items)) throw new Error('service_changed');
            page.items.filter(Boolean).forEach(function (p) {
              if (!p.id || !p.name) return;
              state.playlists.push({ id: p.id, title: p.name, owner: p.owner && p.owner.display_name || '',
                artwork: artwork(p.images), trackCount: p.items && p.items.total || p.tracks && p.tracks.total,
                url: 'https://open.spotify.com/playlist/' + encodeURIComponent(p.id), section: 'Your playlists' });
            });
            offset += page.items.length;
            if (!page.next) { state.complete = true; return; }
            if (!page.items.length) throw new Error('incomplete');
          }
          throw new Error('incomplete');
        }
        state.complete = true;
      })().catch(function (error) { state.error = ['login_required', 'rate_limited', 'incomplete', 'invalid_playlist', 'restricted'].includes(error.message) ? error.message : 'service_changed'; });
    }
  };
})();
