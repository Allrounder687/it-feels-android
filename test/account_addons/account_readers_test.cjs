// Run with: node --test test/account_addons/account_readers_test.cjs
// Synthetic service responses only. No live credentials or copyrighted media.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const { webcrypto } = require('node:crypto');
const { setImmediate: immediate } = require('node:timers/promises');

function create(provider, options = {}) {
  const origin = options.origin || (provider === 'spotify' ? 'https://open.spotify.com' : 'https://music.youtube.com');
  const calls = [];
  const document = options.document || { cookie: 'SAPISID=synthetic', querySelector: () => null, querySelectorAll: () => [], scrollingElement: { scrollTop: 0, clientHeight: 800 } };
  const context = {
    location: { origin, href: origin + '/' }, document, URL, Headers, TextEncoder,
    crypto: webcrypto, setTimeout: (fn) => setTimeout(fn, 0), clearTimeout,
    ytcfg: options.noConfig ? null : { get: (key) => ({ LOGGED_IN: options.authenticated !== false,
      INNERTUBE_CONTEXT: { client: { clientName: 'WEB_REMIX', clientVersion: 'test' } }, SESSION_INDEX: 0 })[key] },
    fetch: async (url, init) => {
      calls.push({ url, init });
      const result = await options.fetch(url, init, calls.length);
      return { ok: !result.status || result.status < 400, status: result.status || 200,
        json: async () => result.body, text: async () => result.text, clone() { return this; } };
    },
  };
  context.window = context;
  vm.createContext(context);
  vm.runInContext(fs.readFileSync(`assets/account_addons/${provider === 'spotify' ? 'spotify' : 'youtube_music'}.js`, 'utf8'), context);
  return { context, calls, addon: context.itFeelsAccount };
}
async function finish(addon) {
  for (let i = 0; i < 500; i++) {
    await immediate(); await new Promise((r) => setTimeout(r, 1));
    const result = addon.snapshot();
    if (result.complete || result.error) return JSON.parse(JSON.stringify(result));
  }
  assert.fail('Reader did not settle');
}
const ytPlaylist = (id, title) => ({ musicTwoRowItemRenderer: {
  title: { runs: [{ text: title }] }, subtitle: { runs: [{ text: 'Curator' }] },
  navigationEndpoint: { browseEndpoint: { browseId: 'VL' + id } },
  thumbnailRenderer: { musicThumbnailRenderer: { thumbnail: { thumbnails: [{ url: 'https://images.example/cover.jpg' }] } } },
} });
const ytTrack = (id, entry, title = 'Original recording') => ({ musicResponsiveListItemRenderer: {
  playlistItemData: { videoId: id, playlistSetVideoId: entry },
  flexColumns: [{ musicResponsiveListItemFlexColumnRenderer: { text: { runs: [{ text: title }] } } },
    { musicResponsiveListItemFlexColumnRenderer: { text: { runs: [{ text: 'Artist' }] } } }],
  fixedColumns: [{ musicResponsiveListItemFixedColumnRenderer: { text: { simpleText: '3:42' } } }],
} });
function spotifyFetch(url) {
  if (url.endsWith('/me')) return { body: { id: 'listener', display_name: 'Synthetic listener' } };
  throw new Error('Unexpected request ' + url);
}
function authorize(context) {
  return context.fetch('https://api.spotify.com/v1/me', { headers: { Authorization: 'Bearer synthetic-token' } });
}

test('addons do not activate on an unrelated origin', () => {
  for (const provider of ['youtube', 'spotify']) {
    assert.equal(create(provider, { origin: 'https://unrelated.example' }).addon, undefined);
  }
});
test('YouTube anonymous state fails closed without requesting a library', async () => {
  const { addon, calls } = create('youtube', { authenticated: false, fetch: () => assert.fail('Anonymous request') });
  addon.start({ mode: 'feed' }); const result = await finish(addon);
  assert.equal(result.error, 'login_required'); assert.equal(calls.length, 0);
});
test('YouTube library follows continuation pages and deduplicates home recommendations', async () => {
  const { addon, calls } = create('youtube', { fetch: (url, init) => {
    const body = JSON.parse(init.body);
    if (body.continuation) return { body: { items: [ytPlaylist('two', 'Second')] } };
    if (body.browseId === 'FEmusic_home') return { body: { items: [ytPlaylist('one', 'First'), ytPlaylist('three', 'Recommended')] } };
    return { body: { items: [ytPlaylist('one', 'First')], continuations: [{ nextContinuationData: { continuation: 'page2' } }] } };
  } });
  addon.start({ mode: 'feed' }); const result = await finish(addon);
  assert.equal(result.complete, true); assert.deepEqual(result.playlists.map((p) => p.id), ['one', 'two', 'three']);
  assert.equal(calls.length, 3); assert.equal(result.playlists[2].section, 'Picked for you');
  assert.ok(calls.every((c) => c.init.credentials === 'include'));
});
test('YouTube repeated recordings and duration survive across pages', async () => {
  const { addon } = create('youtube', { fetch: (url, init) => ({ body: JSON.parse(init.body).continuation
    ? { items: [ytTrack('same', 'second')] }
    : { items: [ytTrack('same', 'first')], continuations: [{ nextContinuationData: { continuation: 'next' } }] } }) });
  addon.start({ mode: 'playlist', id: 'PLvalid' }); const result = await finish(addon);
  assert.equal(result.tracks.length, 2); assert.deepEqual(result.tracks.map((t) => t.entryId), ['first', 'second']);
  assert.equal(result.tracks[0].duration, 222);
});
test('YouTube repeated continuation is an incomplete result, not silent truncation', async () => {
  const { addon } = create('youtube', { fetch: () => ({ body: { continuations: [{ nextContinuationData: { continuation: 'loop' } }] } }) });
  addon.start({ mode: 'playlist', id: 'PLvalid' }); const result = await finish(addon);
  assert.equal(result.error, 'incomplete'); assert.equal(result.complete, false);
});
test('YouTube unavailable tracks are omitted without dropping playable entries', async () => {
  const unavailable = ytTrack('deleted', 'gone'); unavailable.musicResponsiveListItemRenderer.isPlayable = false;
  const { addon } = create('youtube', { fetch: () => ({ body: { items: [unavailable, ytTrack('ok', 'entry')] } }) });
  addon.start({ mode: 'playlist', id: 'PLvalid' }); const result = await finish(addon);
  assert.equal(result.complete, true); assert.equal(result.tracks.length, 1); assert.equal(result.tracks[0].id, 'ok');
});
test('YouTube a rate-limited library remains incomplete and retryable', async () => {
  const { addon } = create('youtube', { fetch: () => ({ status: 429 }) });
  addon.start({ mode: 'feed' }); assert.equal((await finish(addon)).error, 'rate_limited');
});
test('YouTube recommendations failing do not discard a successful library', async () => {
  const { addon } = create('youtube', { fetch: (url, init) => JSON.parse(init.body).browseId === 'FEmusic_home'
    ? { status: 503 } : { body: { items: [ytPlaylist('one', 'Saved')] } } });
  addon.start({ mode: 'feed' }); const result = await finish(addon);
  assert.equal(result.complete, true); assert.equal(result.playlists[0].title, 'Saved');
});
test('malformed playlist identifiers never enter provider requests', async () => {
  for (const provider of ['youtube', 'spotify']) {
    const { addon, context, calls } = create(provider, { fetch: spotifyFetch });
    if (provider === 'spotify') await authorize(context);
    addon.start({ mode: 'playlist', id: '../account?secret' });
    assert.equal((await finish(addon)).error, 'invalid_playlist');
    assert.ok(!calls.some((c) => c.url.includes('../account')));
  }
});
test('Spotify verifies its profile before exposing a usable signed-in session', async () => {
  const { addon, context } = create('spotify', { fetch: spotifyFetch });
  assert.equal(addon.snapshot().authenticated, false);
  await authorize(context); addon.snapshot(); await immediate();
  assert.equal(addon.snapshot().authenticated, true);
  assert.equal(addon.snapshot().accountName, 'Synthetic listener');
  assert.ok(!JSON.stringify(addon.snapshot()).includes('synthetic-token'));
});
test('Spotify observes no bearer token from unrelated third-party requests', async () => {
  const { addon, context } = create('spotify', { fetch: () => ({ body: {} }) });
  await context.fetch('https://unrelated.example/token', { headers: { Authorization: 'Bearer unrelated-secret' } });
  assert.equal(addon.snapshot().authenticated, false);
});
test('Spotify does not repeatedly verify an anonymous/expired token while sign-in is pending', async () => {
  const { addon, context, calls } = create('spotify', { fetch: () => ({ status: 401 }) });
  await authorize(context);
  for (let i = 0; i < 20; i++) { addon.snapshot(); await immediate(); }
  assert.equal(calls.length, 2); // The synthetic web request plus one profile verification.
  assert.equal(addon.snapshot().authenticated, false);
});
test('Spotify a stale initial page session cannot overwrite a fresh web-player token', async () => {
  const document = { cookie: '', querySelector: () => ({ textContent: JSON.stringify({ accessToken: 'stale-token', isAnonymous: false }) }), querySelectorAll: () => [] };
  const { addon, context, calls } = create('spotify', { document, fetch: spotifyFetch });
  await authorize(context); addon.snapshot(); await immediate();
  assert.equal(addon.snapshot().authenticated, true);
  const profile = calls.find((call, index) => index > 0 && call.url.endsWith('/me'));
  assert.equal(profile.init.headers.Authorization, 'Bearer synthetic-token');
});
test('Spotify library pagination preserves followed playlist provenance', async () => {
  const { addon, context } = create('spotify', { fetch: (url) => {
    if (!url.includes('me/playlists')) return spotifyFetch(url);
    const second = url.includes('offset=1');
    return { body: { items: [{ id: second ? 'two' : 'one', name: second ? 'Second' : 'First',
      owner: { display_name: 'Another curator' }, images: [], tracks: { total: 900 } }], next: second ? null : 'next' } };
  } });
  await authorize(context); addon.start({ mode: 'feed' }); const result = await finish(addon);
  assert.equal(result.complete, true); assert.equal(result.playlists.length, 2);
  assert.equal(result.playlists[0].owner, 'Another curator'); assert.equal(result.playlists[0].trackCount, 900);
});
test('Spotify playlist reader retains intentional duplicates and skips unavailable entries', async () => {
  const { addon, context } = create('spotify', { fetch: (url) => url.includes('/items?')
    ? { body: { items: [{ item: { id: 'song', name: 'Recording', artists: [], album: {} } },
      { item: null }, { item: { id: 'song', name: 'Recording', artists: [], album: {} } }], next: null } }
    : spotifyFetch(url) });
  await authorize(context); addon.start({ mode: 'playlist', id: 'valid123' }); const result = await finish(addon);
  assert.equal(result.complete, true); assert.deepEqual(result.tracks.map((t) => t.entryId), ['0', '2']);
});
test('Spotify restricted playlists use observed web-player metadata rather than report empty success', async () => {
  const { addon, context } = create('spotify', { fetch: (url) => {
    if (url.includes('/items?')) return { status: 403 };
    if (url.includes('/pathfinder/')) return { body: { data: { playlistV2: { content: { totalCount: 2,
      items: [{ itemV2: { data: { __typename: 'Track', uri: 'spotify:track:song', name: 'Song', artists: { items: [{ profile: { name: 'Artist' } }] }, albumOfTrack: { name: 'Album', coverArt: { sources: [] } }, trackDuration: { totalMilliseconds: 180000 } } } }, { itemV2: { data: { __typename: 'NotFound' } } }] } } } } };
    return spotifyFetch(url);
  } });
  await authorize(context);
  await context.fetch('https://api-partner.spotify.com/pathfinder/v2/query', { body: JSON.stringify({ variables: { offset: 0 } }) });
  await immediate(); addon.start({ mode: 'playlist', id: 'valid123' }); const result = await finish(addon);
  assert.equal(result.complete, true); assert.equal(result.tracks.length, 1); assert.equal(result.tracks[0].duration, 180);
});
test('Spotify an empty next page is an incomplete result rather than an endless loop', async () => {
  const { addon, context } = create('spotify', { fetch: (url) => url.includes('me/playlists')
    ? { body: { items: [], next: 'next' } } : spotifyFetch(url) });
  await authorize(context); addon.start({ mode: 'feed' }); assert.equal((await finish(addon)).error, 'incomplete');
});
test('Spotify DOM fallback uses absolute row positions and a declared total, preserving repeated tracks', async () => {
  const rows = [2, 3].map((index) => ({
    getAttribute: (name) => name === 'aria-rowindex' ? String(index) : null,
    querySelector: (selector) => selector.includes('/track/') ? { href: 'https://open.spotify.com/track/same', textContent: 'Same recording' } : null,
    querySelectorAll: () => [{ textContent: 'Artist' }],
  }));
  const document = { cookie: '', scrollingElement: { scrollTop: 0, clientHeight: 800 },
    querySelector: (selector) => selector.includes('aria-rowcount') ? { getAttribute: () => '3' } : null,
    querySelectorAll: () => rows,
  };
  const { addon, context } = create('spotify', { document, fetch: (url) => url.includes('/items?') ? { status: 403 } : spotifyFetch(url) });
  await authorize(context); addon.start({ mode: 'playlist', id: 'valid123' });
  const result = await finish(addon);
  assert.equal(result.complete, true); assert.deepEqual(result.tracks.map((t) => t.entryId), ['0', '1']);
  assert.deepEqual(result.tracks.map((t) => t.id), ['same', 'same']);
});
test('Spotify expired sessions request reconnect and do not leak response details', async () => {
  const { addon, context } = create('spotify', { fetch: () => ({ status: 401, body: { secret: 'never-expose' } }) });
  await authorize(context); addon.start({ mode: 'feed' }); const result = await finish(addon);
  assert.equal(result.error, 'login_required'); assert.ok(!JSON.stringify(result).includes('never-expose'));
});
test('both readers enumerate 1,200-entry playlists across 24 pages without truncating repeats', async () => {
  for (const provider of ['youtube', 'spotify']) {
    const { addon, context } = create(provider, { fetch: (url, init) => {
      if (provider === 'spotify' && !url.includes('/items?')) return spotifyFetch(url);
      const body = provider === 'youtube' ? JSON.parse(init.body) : null;
      const offset = provider === 'youtube' ? Number(body.continuation || 0) : Number(new URL(url).searchParams.get('offset'));
      const more = offset + 50 < 1200;
      if (provider === 'youtube') return { body: {
        items: Array.from({ length: 50 }, (_, i) => ytTrack('recording' + ((offset + i) % 10), 'entry' + (offset + i))),
        continuations: more ? [{ nextContinuationData: { continuation: String(offset + 50) } }] : [],
      } };
      return { body: { items: Array.from({ length: 50 }, (_, i) => ({ item: {
        id: 'recording' + ((offset + i) % 10), name: 'Original recording', artists: [], album: {},
      } })), next: more ? 'next' : null } };
    } });
    if (provider === 'spotify') await authorize(context);
    addon.start({ mode: 'playlist', id: 'valid123' });
    const result = await finish(addon);
    assert.equal(result.complete, true, provider);
    assert.equal(result.tracks.length, 1200, provider);
    assert.equal(new Set(result.tracks.map((t) => t.entryId)).size, 1200, provider);
    assert.equal(new Set(result.tracks.map((t) => t.id)).size, 10, provider);
  }
});
test('YouTube discovery works anonymously and includes long single-video mixes', async () => {
  const { addon } = create('youtube', { authenticated: false, fetch: (url) => ({ body: url.includes('/search?')
    ? { items: [{ videoRenderer: { videoId: 'mix123', title: { simpleText: 'One hour acoustic mix' }, lengthText: { simpleText: '1:00:00' } } }] }
    : { items: [ytPlaylist('public', 'Public curated playlist')] } }) });
  addon.start({ mode: 'discover' }); const result = await finish(addon);
  assert.equal(result.complete, true); assert.equal(result.authenticated, false);
  assert.ok(result.playlists.every((p) => p.requiresAccount === false));
  assert.equal(result.playlists.find((p) => p.videoId).videoId, 'mix123');
});
test('a public playlist can be read without connecting an account', async () => {
  const { addon } = create('youtube', { authenticated: false, fetch: () => ({ body: { items: [ytTrack('song', 'entry')] } }) });
  addon.start({ mode: 'playlist', id: 'public', allowAnonymous: true });
  const result = await finish(addon); assert.equal(result.tracks.length, 1); assert.equal(result.complete, true);
});
test('a mix retains its single audio identity and parses timestamped track descriptions', async () => {
  const { addon } = create('youtube', { authenticated: false, fetch: (url) => ({ body: url.includes('/player?')
    ? { videoDetails: { title: 'Nonstop mix', author: 'Curator', lengthSeconds: '600', shortDescription: '0:00 Artist One - Blue Sky\n03:00 Artist Two - Golden Road\n06:30 Artist Three - Morning' } }
    : {} }) });
  addon.start({ mode: 'mix', videoId: 'mix123' }); const result = await finish(addon);
  assert.equal(result.complete, true); assert.equal(result.tracks.length, 1); assert.equal(result.tracks[0].id, 'mix123');
  assert.equal(result.tracks[0].duration, 600);
  assert.deepEqual(result.chapters.map((c) => [c.start, c.end]), [[0, 180], [180, 390], [390, 600]]);
  assert.equal(result.chapters[1].title, 'Artist Two - Golden Road');
});
test('native chapter markers take priority and markers beyond the mix duration are ignored', async () => {
  const { addon } = create('youtube', { fetch: (url) => ({ body: url.includes('/player?')
    ? { videoDetails: { title: 'Mix', lengthSeconds: '600', shortDescription: '0:00 Wrong description\n03:00 Wrong second' } }
    : { markers: [{ chapterRenderer: { title: { simpleText: 'Correct first' }, timeRangeStartMillis: 0 } },
      { chapterRenderer: { title: { simpleText: 'Correct second' }, timeRangeStartMillis: 300000 } },
      { chapterRenderer: { title: { simpleText: 'Outside mix' }, timeRangeStartMillis: 900000 } }] } }) });
  addon.start({ mode: 'mix', videoId: 'mix123' }); const result = await finish(addon);
  assert.deepEqual(result.chapters.map((c) => c.title), ['Correct first', 'Correct second']);
});
test('mixes without real chapter metadata do not receive invented song lists', async () => {
  const { addon } = create('youtube', { fetch: (url) => ({ body: url.includes('/player?')
    ? { videoDetails: { title: 'Unchaptered mix', lengthSeconds: '3600', shortDescription: 'Enjoy this mix!' } } : {} }) });
  addon.start({ mode: 'mix', videoId: 'mix123' }); const result = await finish(addon);
  assert.equal(result.tracks.length, 1); assert.deepEqual(result.chapters, []);
});

 test('lightweight reader bootstraps JSON config without running page scripts', async () => {
 const fixture = create('youtube', {noConfig:true,authenticated:false,fetch:async (url) => url === '/' ? {text: '<script>ytcfg.set('+JSON.stringify({INNERTUBE_CONTEXT:{client:{clientName:'WEB_REMIX',clientVersion:'test'}},LOGGED_IN:false})+');</script><script>throw new Error("must not execute");</script>'} : {body:{}} });
 fixture.addon.start({mode:'discover'});
 const result=await finish(fixture.addon);
 assert.equal(result.complete,true); assert.equal(result.error,undefined);
 assert.equal(fixture.calls.filter(c => c.url === '/').length,1);
 });
 test('lightweight reader reports missing configuration without loading a music SPA', async () => {
 const fixture=create('youtube',{noConfig:true,fetch:async()=>({text:'<html>Unavailable</html>'})});
 fixture.addon.start({mode:'discover'});
 assert.equal((await finish(fixture.addon)).error,'service_changed');
 assert.equal(fixture.calls.length,1);
 });

 test('session audio chooses only direct audio formats, preserving the video identity', async () => {
 const fixture=create('youtube',{fetch:async(url,init)=>{const request=JSON.parse(init.body);assert.equal(request.videoId,'abcdefghijk');return {body:{streamingData:{adaptiveFormats:[{url:'https://cdn.example/video',mimeType:'video/mp4',bitrate:999999},{url:'https://cdn.example/audio.m4a',mimeType:'audio/mp4',bitrate:128000},{signatureCipher:'not-decoded',mimeType:'audio/mp4',bitrate:256000}]}}};}});
 fixture.addon.start({mode:'audio',videoId:'abcdefghijk'});
 const result=await finish(fixture.addon);assert.equal(result.audioUrl,'https://cdn.example/audio.m4a');assert.equal(result.complete,true);assert.equal(result.tracks.length,0);
 });
 test('blocked or cipher-only session audio produces no invented URL', async () => {
 const fixture=create('youtube',{fetch:async()=>({body:{playabilityStatus:{status:'LOGIN_REQUIRED'},streamingData:{adaptiveFormats:[{signatureCipher:'blocked',mimeType:'audio/mp4'}]}}})});
 fixture.addon.start({mode:'audio',videoId:'abcdefghijk'});assert.equal((await finish(fixture.addon)).audioUrl,null);
 });
