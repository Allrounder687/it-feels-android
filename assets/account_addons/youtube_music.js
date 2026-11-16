/* IT Feels account addon v1. No audio extraction. Runs only on music.youtube.com.
 * Original implementation; architecture inspired by Metrolist/InnerTune.
 * Account data is read on-device from the user's authenticated service session.
 */
(function () {
  'use strict';
  if (location.origin !== 'https://music.youtube.com') return;
  var state = { authenticated: false, accountName: '', playlists: [], tracks: [], complete: false };
  var running = false, publicDiscovery = false;
  function text(v) { return v && (v.simpleText || (v.runs || []).map(function (r) { return r.text || ''; }).join('')) || ''; }
  function walk(value, visit) {
    if (!value || typeof value !== 'object') return;
    if (Array.isArray(value)) { value.forEach(function (v) { walk(v, visit); }); return; }
    visit(value);
    Object.keys(value).forEach(function (k) { walk(value[k], visit); });
  }
  function image(r) {
    var result = '';
    walk(r, function (o) { if (Array.isArray(o.thumbnails) && o.thumbnails.length) result = o.thumbnails[o.thumbnails.length - 1].url || result; });
    return result;
  }
  function config(key) { return window.ytcfg && window.ytcfg.get ? window.ytcfg.get(key) : null; }
  function authenticated() { return config('LOGGED_IN') === true || config('SESSION_INDEX') != null && !!config('DELEGATED_SESSION_ID'); }
  async function request(endpoint, body) {
    var context = config('INNERTUBE_CONTEXT');
    if (!context || !context.client) throw new Error('service_changed');
    var headers = { 'Content-Type': 'application/json', 'X-Goog-AuthUser': String(config('SESSION_INDEX') || 0) };
    var cookie = document.cookie.match(/(?:^|;\s*)(?:SAPISID|__Secure-3PAPISID)=([^;]+)/);
    if (cookie) {
      var seconds = Math.floor(Date.now() / 1000);
      var bytes = new TextEncoder().encode(seconds + ' ' + cookie[1] + ' ' + location.origin);
      var digest = await crypto.subtle.digest('SHA-1', bytes);
      var hash = Array.from(new Uint8Array(digest)).map(function (b) { return b.toString(16).padStart(2, '0'); }).join('');
      headers.Authorization = 'SAPISIDHASH ' + seconds + '_' + hash;
    }
    var pageId = config('DELEGATED_SESSION_ID');
    if (pageId) headers['X-Goog-PageId'] = pageId;
    body.context = context;
    var key = config('INNERTUBE_API_KEY');
    var response = await fetch('/youtubei/v1/' + endpoint + '?prettyPrint=false' + (key ? '&key=' + encodeURIComponent(key) : ''),
      { method: 'POST', credentials: 'include', headers: headers, body: JSON.stringify(body) });
    if (response.status === 401 || response.status === 403) throw new Error('login_required');
    if (!response.ok) throw new Error(response.status === 429 ? 'rate_limited' : 'unavailable');
    return response.json();
  }
  function browse(body) { return request('browse', body); }
  function playlists(data, section) {
    var known = new Set(state.playlists.map(function (p) { return p.id; }));
    walk(data, function (o) {
      var r = o.musicTwoRowItemRenderer || o.gridPlaylistRenderer || o.playlistRenderer || o.musicResponsiveListItemRenderer;
      if (!r) return;
      var id = r.playlistId || r.navigationEndpoint && r.navigationEndpoint.browseEndpoint && r.navigationEndpoint.browseEndpoint.browseId;
      if (!id || (!r.playlistId && id.indexOf('VL') !== 0)) return;
      id = id.replace(/^VL/, '');
      var columns = (r.flexColumns || []).map(function (c) { return text(c.musicResponsiveListItemFlexColumnRenderer && c.musicResponsiveListItemFlexColumnRenderer.text); });
      var title = text(r.title) || columns[0];
      if (!title || known.has(id)) return;
      known.add(id);
      state.playlists.push({ id: id, title: title, owner: text(r.subtitle || r.shortBylineText) || columns[1] || '',
        artwork: image(r.thumbnailRenderer || r.thumbnail || r.thumbnails), url: 'https://music.youtube.com/playlist?list=' + encodeURIComponent(id), section: section, requiresAccount: !publicDiscovery || state.authenticated });
    });
  }
  function duration(s) {
    var numbers = s.split(':').map(Number);
    return numbers.every(Number.isFinite) ? numbers.reduce(function (a, b) { return a * 60 + b; }, 0) : 0;
  }
  function tracks(data, page) {
    var index = 0;
    walk(data, function (o) {
      var r = o.musicResponsiveListItemRenderer || o.playlistVideoRenderer;
      if (!r) return;
      var video = r.playlistItemData && r.playlistItemData.videoId || r.videoId;
      if (!video || r.isPlayable === false || r.musicItemRendererDisplayPolicy === 'MUSIC_ITEM_RENDERER_DISPLAY_POLICY_GREY_OUT') return;
      var columns = (r.flexColumns || []).map(function (c) { return text(c.musicResponsiveListItemFlexColumnRenderer && c.musicResponsiveListItemFlexColumnRenderer.text); });
      var title = columns[0] || text(r.title);
      if (!title || title === 'Deleted video' || title === 'Private video') return;
      var fixed = r.fixedColumns && r.fixedColumns[0];
      var time = text(fixed && fixed.musicResponsiveListItemFixedColumnRenderer.text) || text(r.lengthText);
      var entry = r.playlistItemData && r.playlistItemData.playlistSetVideoId || page + ':' + index;
      index++;
      state.tracks.push({ entryId: entry, id: video, title: title,
        artist: columns[1] || text(r.shortBylineText), album: columns[2] || '', duration: duration(time), artwork: image(r.thumbnail) });
    });
  }
  function continuation(data) {
    var token = null;
    walk(data, function (o) {
      if (token) return;
      token = o.nextContinuationData && o.nextContinuationData.continuation ||
        o.continuationItemRenderer && o.continuationItemRenderer.continuationEndpoint &&
        o.continuationItemRenderer.continuationEndpoint.continuationCommand && o.continuationItemRenderer.continuationEndpoint.continuationCommand.token || null;
    });
    return token;
  }
  function mixVideos(data) {
    var known = new Set(state.playlists.map(function (p) { return p.id; }));
    walk(data, function (o) {
      var r = o.musicResponsiveListItemRenderer || o.videoRenderer;
      if (!r) return;
      var endpoint = r.navigationEndpoint && r.navigationEndpoint.watchEndpoint;
      var id = r.videoId || endpoint && endpoint.videoId || r.playlistItemData && r.playlistItemData.videoId;
      var columns = (r.flexColumns || []).map(function (c) { return text(c.musicResponsiveListItemFlexColumnRenderer && c.musicResponsiveListItemFlexColumnRenderer.text); });
      var title = text(r.title) || columns[0];
      var length = text(r.lengthText) || columns.join(' ').match(/\b(?:\d+:)?\d{1,2}:\d{2}\b/);
      var seconds = duration(Array.isArray(length) ? length[0] : length || '');
      if (!id || !title || seconds < 1200 || known.has('video:' + id)) return;
      known.add('video:' + id);
      state.playlists.push({ id: 'video:' + id, videoId: id, title: title, trackCount: 1,
        owner: 'Long-form music mix', artwork: image(r.thumbnail), requiresAccount: false,
        url: 'https://music.youtube.com/watch?v=' + encodeURIComponent(id), section: 'Long mixes' });
    });
  }
  function chapters(description, nativeData, total) {
    var markers = new Map();
    walk(nativeData, function (o) {
      var r = o.chapterRenderer;
      if (r && Number.isFinite(r.timeRangeStartMillis)) markers.set(Math.floor(r.timeRangeStartMillis / 1000), text(r.title));
      var m = o.macroMarkersListItemRenderer;
      if (m && text(m.timeDescription)) markers.set(duration(text(m.timeDescription)), text(m.title));
    });
    if (markers.size < 2) {
      String(description || '').split('\n').forEach(function (line) {
        var match = line.match(/(?:^|\s|\[|\()((?:\d{1,2}:)?\d{1,2}:\d{2})(?:\]|\))?\s*[-–—|:]?\s*(.*)$/);
        if (!match) return;
        var title = (match[2] || line.slice(0, match.index)).replace(/^\s*[-–—|\[\]()]+|[-–—|\[\]()]+\s*$/g, '').trim();
        var start = duration(match[1]);
        if (title && (!total || start < total)) markers.set(start, title);
      });
    }
    var positions = Array.from(markers.keys()).filter(function (p) { return p >= 0 && (!total || p < total); }).sort(function (a, b) { return a - b; });
    if (positions.length < 2) return [];
    return positions.map(function (p, i) { return { title: markers.get(p), start: p, end: positions[i + 1] || total || null }; });
  }
  async function readMix(id) {
    if (!/^[A-Za-z0-9_-]+$/.test(id || '')) throw new Error('invalid_playlist');
    var response = await request('player', { videoId: id });
    var details = response.videoDetails;
    if (!details || !details.title) throw new Error('service_changed');
    var total = Number(details.lengthSeconds) || 0;
    state.tracks = [{ entryId: 'full_mix', id: id, title: details.title, artist: details.author || '',
      duration: total, artwork: image(details.thumbnail), album: 'Full mix' }];
    var next = {};
    try { next = await request('next', { videoId: id }); } catch (_) { /* Description timestamps remain available. */ }
    state.chapters = chapters(details.shortDescription, next, total);
  }
  async function readPages(id, mode, section) {
    var body = { browseId: id }, seen = new Set();
    for (var page = 0; page < 200; page++) {
      var data = await browse(body);
      if (mode === 'playlist') tracks(data, page); else playlists(data, section);
      var token = continuation(data);
      if (!token) return;
      if (seen.has(token)) throw new Error('incomplete');
      seen.add(token); body = { continuation: token };
      if (state.tracks.length > 10000 || state.playlists.length > 3000) throw new Error('incomplete');
      if (section === 'Picked for you' && page >= 2) return;
    }
    throw new Error('incomplete');
  }
  window.itFeelsAccount = {
    snapshot: function () {
      if (!running) {
        state.authenticated = authenticated();
        var account = document.querySelector('ytmusic-settings-button img');
        state.accountName = account && account.alt || '';
      }
      return state;
    },
    start: function (input) {
      if (running) return;
      running = true;
      (async function () {
        for (var i = 0; i < 40 && !config('INNERTUBE_CONTEXT'); i++) await new Promise(function (r) { setTimeout(r, 250); });
        state.authenticated = authenticated();
        publicDiscovery = input.mode === 'discover' || input.allowAnonymous === true;
        if (input.mode === 'discover') {
          try { await readPages('FEmusic_home', 'feed', 'Picked for you'); } catch (_) { /* Public search can still work when home requires a session. */ }
          try { playlists(await request('search', { query: 'popular music playlists' }), 'Public curated playlists'); } catch (_) { /* Keep other discovery results. */ }
          try { mixVideos(await request('search', { query: 'nonstop music mix full playlist' })); } catch (_) { /* Normal playlist discovery still works. */ }
          state.complete = true; return;
        }
        if (input.mode === 'mix') { await readMix(input.videoId); state.complete = true; return; }
        if (!state.authenticated && !publicDiscovery) throw new Error('login_required');
        if (input.mode === 'playlist') {
          if (!/^[A-Za-z0-9_-]+$/.test(input.id || '')) throw new Error('invalid_playlist');
          await readPages('VL' + input.id, 'playlist');
        } else {
          await readPages('FEmusic_liked_playlists', 'feed', 'Your playlists');
          // Recommendations are an enhancement; their failure must not hide the library.
          try { await readPages('FEmusic_home', 'feed', 'Picked for you'); } catch (_) { /* Library remains current. */ }
        }
        state.complete = true;
      })().catch(function (error) { state.error = ['login_required', 'rate_limited', 'incomplete', 'invalid_playlist'].includes(error.message) ? error.message : 'service_changed'; });
    }
  };
})();
