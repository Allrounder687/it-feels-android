import { NativeDatabaseProvider } from './providers/native_db';
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { SaavnProvider } from './providers/saavn';
import { YoutubeProvider } from './providers/youtube';
import { SpotifyProvider } from './providers/spotify';
import { LrcLibProvider } from './providers/lrclib';
import { MusixmatchProvider } from './providers/musixmatch';
import { LastfmProvider } from './providers/lastfm';
import { DeezerProvider } from './providers/deezer';
import { ListenBrainzProvider } from './providers/listenbrainz';
import { telegram } from './telegram';

type Bindings = {
  SEARCH_CACHE: KVNamespace;
  YT_DLP_BASE_URL?: string;
  API_SECRET: string;
  OPENAI_API_KEY?: string;
  ANTHROPIC_API_KEY?: string;
  GEMINI_API_KEY?: string;
  RESEND_API_KEY?: string;
  RAZORPAY_KEY_ID?: string;
  RAZORPAY_KEY_SECRET?: string;
  LASTFM_API_KEY?: string;
  LASTFM_SHARED_SECRET?: string;
  SPOTIFY_CLIENT_ID?: string;
  SPOTIFY_CLIENT_SECRET?: string;
};

// Spotify Token Cache (per isolate)
let cachedSpotifyToken: string | null = null;
let spotifyTokenExpiry = 0; // Unix timestamp in ms

const app = new Hono<{ Bindings: Bindings }>();

// Enable CORS for mobile app access
app.use('*', cors());

// Mount Telegram Webhook (outside API security checks)
app.route('/telegram', telegram);

// Root Landing Page (Satisfies Razorpay "Business Website" requirement)
app.get('/', (c) => {
  return c.html(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>IT Feels Music - Download App</title>
      <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #0f0f13; color: white; text-align: center; padding: 50px; }
        .container { max-width: 600px; margin: 0 auto; background: #1a1a20; padding: 40px; border-radius: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
        h1 { color: #fff; margin-bottom: 10px; font-size: 2.5em; }
        p { color: #aaa; margin-bottom: 30px; font-size: 1.1em; line-height: 1.6; }
        a.download-btn { display: inline-block; background-color: #ff3b30; color: white; padding: 15px 30px; text-decoration: none; border-radius: 30px; font-weight: bold; font-size: 1.2em; transition: 0.3s; }
        a.download-btn:hover { background-color: #ff453a; transform: translateY(-2px); box-shadow: 0 5px 15px rgba(255, 59, 48, 0.4); }
        .footer { margin-top: 40px; font-size: 0.9em; color: #666; }
        .footer a { color: #888; text-decoration: none; margin: 0 10px; }
        .footer a:hover { color: #fff; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>IT Feels Music</h1>
        <p>The ultimate ad-free, high-res music streaming experience. Sync your vibes, connect with friends, and discover new tracks daily.</p>
        <a href="https://github.com/Allrounder687/it-feels-android/releases/latest" class="download-btn" target="_blank">Download for Android</a>
        
        <div class="footer">
          <p>© 2026 IT Feels Music. All rights reserved.</p>
          <p>
            <a href="/privacy">Privacy Policy</a> | 
            <a href="/terms">Terms of Service</a>
          </p>
        </div>
      </div>
    </body>
    </html>
  `);
});

// Basic Privacy & Terms Pages for KYC
app.get('/privacy', (c) => c.html('<body style="background:#0f0f13;color:white;font-family:sans-serif;padding:40px;max-width:800px;margin:auto;"><h1>Privacy Policy</h1><p>We respect your privacy. No data is sold to third parties.</p></body>'));
app.get('/terms', (c) => c.html('<body style="background:#0f0f13;color:white;font-family:sans-serif;padding:40px;max-width:800px;margin:auto;"><h1>Terms of Service</h1><p>By using IT Feels, you agree to play good music.</p></body>'));

// API Security Middleware
app.use('/api/*', async (c, next) => {
  const secret = c.req.header('X-Feels-Secret');
  if (c.env.API_SECRET && secret !== c.env.API_SECRET) {
    return c.json({ error: 'Unauthorized', message: 'Invalid or missing API secret' }, 401);
  }
  await next();
});

// Health Check
app.get('/health', (c) => {
  return c.json({
    status: 'ok',
    service: 'FEELS Cloud Proxy Engine',
    version: '1.2.0',
    providers: ['saavn', 'youtube', 'spotify', 'lrclib', 'musixmatch'],
    videoSupport: true,
    ageRestrictionBypass: true,
    timestamp: new Date().toISOString(),
  });
});

// Deezer Proxy
app.get('/api/v1/deezer/*', async (c) => {
  const path = c.req.path.replace('/api/v1/deezer/', '');
  const query = new URL(c.req.url).searchParams;
  try {
    const data = await DeezerProvider.proxy(path, query);
    return c.json(data);
  } catch (e: any) {
    return c.json({ error: e.message }, 500);
  }
});

// ListenBrainz Proxy
app.get('/api/v1/listenbrainz/*', async (c) => {
  const path = c.req.path.replace('/api/v1/listenbrainz/', '');
  const query = new URL(c.req.url).searchParams;
  try {
    const data = await ListenBrainzProvider.proxy(path, query);
    return c.json(data);
  } catch (e: any) {
    return c.json({ error: e.message }, 500);
  }
});

// Premium Verification Endpoint
app.get('/api/v1/premium/verify', async (c) => {
  const uid = c.req.query('uid');
  const authHeader = c.req.header('Authorization');
  
  if (!uid || !authHeader) {
    return c.json({ error: 'Missing uid or Authorization header' }, 400);
  }

  try {
    const firestoreUrl = `https://firestore.googleapis.com/v1/projects/it-feels/databases/(default)/documents/users/${uid}`;
    
    const response = await fetch(firestoreUrl, {
      method: 'GET',
      headers: {
        'Authorization': authHeader,
        'Accept': 'application/json'
      }
    });

    if (!response.ok) {
      if (response.status === 404) {
         return c.json({ isPremium: false, reason: 'Document not found' });
      }
      throw new Error(`Firestore API error: ${response.status}`);
    }

    const data = await response.json();
    
    // Firestore REST API represents booleans like: { fields: { isPremium: { booleanValue: true } } }
    const isPremium = data.fields?.isPremium?.booleanValue === true;
    const isPremiumFamily = data.fields?.isPremiumFamily?.booleanValue === true;

    return c.json({ 
      isPremium: isPremium || isPremiumFamily,
      success: true 
    });

  } catch (error: any) {
    console.error('Error verifying premium status:', error);
    return c.json({ error: 'Failed to verify premium status', details: error.message }, 500);
  }
});

// Spotify Token Endpoint
app.get('/spotify/token', async (c) => {
  const clientId = c.env.SPOTIFY_CLIENT_ID;
  const clientSecret = c.env.SPOTIFY_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    return c.json({ error: 'Spotify credentials not configured on the server' }, 500);
  }

  const now = Date.now();

  // Check if token is cached and valid (expires in > 60 seconds)
  if (cachedSpotifyToken && (spotifyTokenExpiry - now > 60000)) {
    return c.json({ 
      access_token: cachedSpotifyToken, 
      expires_in: Math.floor((spotifyTokenExpiry - now) / 1000) 
    });
  }

  try {
    const cleanId = clientId.replace(/[^\x00-\x7F]/g, "").trim();
    const cleanSecret = clientSecret.replace(/[^\x00-\x7F]/g, "").trim();

    const response = await fetch('https://accounts.spotify.com/api/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Basic ' + btoa(`${cleanId}:${cleanSecret}`)
      },
      body: 'grant_type=client_credentials'
    });

    if (!response.ok) {
      throw new Error(`Spotify API error: ${response.status}`);
    }

    const data = await response.json() as any;
    cachedSpotifyToken = data.access_token;
    spotifyTokenExpiry = now + (data.expires_in * 1000);

    return c.json({ 
      access_token: cachedSpotifyToken, 
      expires_in: data.expires_in 
    });
  } catch (error: any) {
    console.error('Error fetching Spotify token:', error);
    return c.json({ error: 'Failed to fetch Spotify token', details: error.message }, 500);
  }
});

// Last.fm Integration
app.post('/api/v1/lastfm/auth', async (c) => {
  try {
    if (!c.env.LASTFM_API_KEY || !c.env.LASTFM_SHARED_SECRET) {
      return c.json({ error: 'Configuration Error', message: 'Last.fm keys not configured' }, 500);
    }
    const body = await c.req.json();
    const { username, password } = body;
    if (!username || !password) return c.json({ error: 'Missing credentials' }, 400);

    const provider = new LastfmProvider();
    const res = await provider.authenticate(username, password, c.env.LASTFM_API_KEY, c.env.LASTFM_SHARED_SECRET);
    return c.json(res);
  } catch (error: any) {
    return c.json({ error: 'Last.fm Auth Error', message: error.message }, 500);
  }
});

app.post('/api/v1/lastfm/nowplaying', async (c) => {
  try {
    if (!c.env.LASTFM_API_KEY || !c.env.LASTFM_SHARED_SECRET) {
      return c.json({ error: 'Configuration Error', message: 'Last.fm keys not configured' }, 500);
    }
    const body = await c.req.json();
    const { sessionKey, track, artist, album } = body;
    if (!sessionKey || !track || !artist) return c.json({ error: 'Missing parameters' }, 400);

    const provider = new LastfmProvider();
    const res = await provider.updateNowPlaying(sessionKey, track, artist, c.env.LASTFM_API_KEY, c.env.LASTFM_SHARED_SECRET, album);
    return c.json(res);
  } catch (error: any) {
    return c.json({ error: 'Last.fm Error', message: error.message }, 500);
  }
});

app.post('/api/v1/lastfm/scrobble', async (c) => {
  try {
    if (!c.env.LASTFM_API_KEY || !c.env.LASTFM_SHARED_SECRET) {
      return c.json({ error: 'Configuration Error', message: 'Last.fm keys not configured' }, 500);
    }
    const body = await c.req.json();
    const { sessionKey, track, artist, timestamp, album } = body;
    if (!sessionKey || !track || !artist || !timestamp) return c.json({ error: 'Missing parameters' }, 400);

    const provider = new LastfmProvider();
    const res = await provider.scrobble(sessionKey, track, artist, timestamp, c.env.LASTFM_API_KEY, c.env.LASTFM_SHARED_SECRET, album);
    return c.json(res);
  } catch (error: any) {
    return c.json({ error: 'Last.fm Error', message: error.message }, 500);
  }
});

// Email Service (Resend)
app.post('/api/v1/send-email', async (c) => {
  try {
    if (!c.env.RESEND_API_KEY) {
      return c.json({ error: 'Configuration Error', message: 'RESEND_API_KEY is not configured on the server.' }, 500);
    }

    const body = await c.req.json();
    const { to, subject, html } = body;

    if (!to || !subject || !html) {
      return c.json({ error: 'Bad Request', message: 'Missing required fields: to, subject, or html' }, 400);
    }

    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${c.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: 'IT Feels Music <hello@it-feels.com>',
        to: [to],
        subject: subject,
        html: html
      })
    });

    const data = await response.json();
    if (!response.ok) {
      return c.json({ error: 'Email Failed', details: data }, response.status as any);
    }

    return c.json({ success: true, id: (data as any).id });
  } catch (error: any) {
    return c.json({ error: 'Internal Server Error', message: error.message }, 500);
  }
});

// Razorpay Order Generation
app.post('/api/v1/razorpay/order', async (c) => {
  try {
    if (!c.env.RAZORPAY_KEY_ID || !c.env.RAZORPAY_KEY_SECRET) {
      return c.json({ error: 'Configuration Error', message: 'Razorpay keys not configured' }, 500);
    }

    const body = await c.req.json();
    const { amount, currency = 'INR', receipt } = body;

    if (!amount) {
      return c.json({ error: 'Bad Request', message: 'Amount is required (in paise)' }, 400);
    }

    const response = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Basic ' + btoa(`${c.env.RAZORPAY_KEY_ID}:${c.env.RAZORPAY_KEY_SECRET}`)
      },
      body: JSON.stringify({
        amount,
        currency,
        receipt: receipt || `rcpt_${Date.now()}`
      })
    });

    const data = await response.json();
    if (!response.ok) {
      return c.json({ error: 'Razorpay Error', details: data }, response.status as any);
    }

    return c.json(data);
  } catch (error: any) {
    return c.json({ error: 'Internal Server Error', message: error.message }, 500);
  }
});

// Sources Directory (Dynamic source manifest registry)
app.get('/api/v1/sources', (c) => {
  return c.json([
    {
      source_id: 'in.itfeels.provider.saavn',
      source_name: 'SaavnProvider',
      source_type: 'DOWNLOADABLE_PROVIDER',
      version: '1.0.0',
      enabledByDefault: true,
    },
    {
      source_id: 'in.itfeels.provider.youtube',
      source_name: 'YoutubeProvider',
      source_type: 'DOWNLOADABLE_PROVIDER',
      version: '1.2.0',
      videoSupported: true,
      ageBypass: true,
      enabledByDefault: true,
    },
    {
      source_id: 'in.itfeels.provider.spotify',
      source_name: 'SpotifyProvider',
      source_type: 'QUERYABLE_PROVIDER',
      version: '1.0.0',
      enabledByDefault: true,
      extraDeps: [
        {
          source_id: 'in.itfeels.provider.saavn',
          source_type: 'DOWNLOADABLE_PROVIDER',
        },
        {
          source_id: 'in.itfeels.provider.youtube',
          source_type: 'DOWNLOADABLE_PROVIDER',
        },
      ],
    },
    {
      source_id: 'in.itfeels.provider.lrclib',
      source_name: 'LrcLibLyricsProvider',
      source_type: 'PROVIDER',
      version: '1.0.0',
      enabledByDefault: true,
    },
    {
      source_id: 'in.itfeels.provider.musixmatch',
      source_name: 'MusixmatchLyricsProvider',
      source_type: 'PROVIDER',
      version: '1.0.0',
      enabledByDefault: true,
    },
  ]);
});

// Multi-Source Search Route
app.get('/api/v1/search', async (c) => {
  const query = c.req.query('query');
  const page = parseInt(c.req.query('page') || '1', 10);
  const limit = parseInt(c.req.query('limit') || '20', 10);
  const provider = c.req.query('provider') || 'all';

  if (!query) {
    return c.json({ error: 'Query parameter is required' }, 400);
  }

  const cacheKey = `search:${provider}:${query}:${page}:${limit}`;
  const cached = await c.env.SEARCH_CACHE.get(cacheKey, 'json');
  if (cached) {
    return c.json(cached);
  }

  try {
    if (provider === 'saavn') {
      const results = await SaavnProvider.search(query, page, limit);
      const res = { success: true, query, provider: 'saavn', results };
      c.executionCtx.waitUntil(c.env.SEARCH_CACHE.put(cacheKey, JSON.stringify(res), { expirationTtl: 86400 }));
      return c.json(res);
    }

    if (provider === 'youtube') {
      const results = await YoutubeProvider.search(query, limit);
      const res = { success: true, query, provider: 'youtube', results };
      c.executionCtx.waitUntil(c.env.SEARCH_CACHE.put(cacheKey, JSON.stringify(res), { expirationTtl: 86400 }));
      return c.json(res);
    }

    if (provider === 'spotify') {
      const results = await SpotifyProvider.search(query, limit);
      const res = { success: true, query, provider: 'spotify', results };
      c.executionCtx.waitUntil(c.env.SEARCH_CACHE.put(cacheKey, JSON.stringify(res), { expirationTtl: 86400 }));
      return c.json(res);
    }

    // Default: 'all' -> Query Saavn, YouTube, and Spotify in parallel
    const [saavnRes, ytRes, spotifyRes] = await Promise.allSettled([
      SaavnProvider.search(query, page, limit),
      YoutubeProvider.search(query, limit),
      SpotifyProvider.search(query, limit),
    ]);

    const saavnList = saavnRes.status === 'fulfilled' ? saavnRes.value : [];
    const ytList = ytRes.status === 'fulfilled' ? ytRes.value : [];
    const spotifyList = spotifyRes.status === 'fulfilled' ? spotifyRes.value : [];

    const combined = [...saavnList, ...ytList, ...spotifyList];

    const res = {
      success: true,
      query,
      provider: 'all',
      totalCount: combined.length,
      results: combined,
    };
    c.executionCtx.waitUntil(c.env.SEARCH_CACHE.put(cacheKey, JSON.stringify(res), { expirationTtl: 86400 }));
    return c.json(res);
  } catch (e: any) {
    return c.json({ error: 'Search failed', details: e.message }, 500);
  }
});

// Video Stream Resolution Route (with Age Restriction Bypass)
// Priority: 1) Direct Render yt-dlp proxy (for high quality/4K), 2) Cloudflare + YoutubeProvider (Piped/Invidious/InnerTube)
app.get('/api/v1/video', async (c) => {
  const id = c.req.query('id');
  const query = c.req.query('query');
  const ytDlpUrl = c.env.YT_DLP_BASE_URL || ''; // Set via Render environment variable

  if (!id && !query) {
    return c.json({ error: 'Either id or query parameter is required' }, 400);
  }

  try {
    let videoId = id || '';
    if (query && !videoId) {
      const searchRes = await YoutubeProvider.searchVideos(query, 1);
      if (searchRes.length > 0) {
        videoId = searchRes[0].id;
      }
    }

    if (!videoId) {
      return c.json({ error: 'Video not found' }, 404);
    }

    // PRIORITY 1: Try Render yt-dlp backend first for high-quality 4K/muxed MP4 streams
    if (ytDlpUrl && ytDlpUrl !== '') {
      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 15000);
        const ytRes = await fetch(`${ytDlpUrl}/api/streams?videoId=${videoId}`, {
          headers: { 'User-Agent': 'Mozilla/5.0', 'X-Feels-Secret': 'development_secret_123' },
          signal: controller.signal,
        });
        clearTimeout(timeoutId);
        if (ytRes.ok) {
          const ytData = await ytRes.json() as any;
          if (ytData['streams'] && (ytData['streams'] as Array<any>).length > 0) {
            console.log('[Cloudflare] Render yt-dlp proxy returned high-quality streams - using this');
            return c.json({
              success: true,
              id: videoId,
              title: ytData['title'] || 'Music Video',
              streams: ytData['streams'],
              audioUrl: ytData['audioUrl'] || '',
            });
          }
        }
      } catch (e) {
        console.log('[Cloudflare] Render yt-dlp fetch failed, falling back to YoutubeProvider: ' + (e as Error).message);
      }
    }

    // PRIORITY 2: Use Cloudflare worker-local YouTube provider (Piped, Invidious, InnerTube)
    const videoData = await YoutubeProvider.getVideoStreams(videoId);
    return c.json({
      success: true,
      id: videoId,
      title: videoData.title,
      streams: videoData.streams,
      audioUrl: videoData.audioUrl || '',
    });
  } catch (e: any) {
    return c.json({ error: 'Video stream resolution failed', details: e.message }, 500);
  }
});

// Video Search Route for Dedicated Videos Tab
app.get('/api/v1/videos/search', async (c) => {
  const query = c.req.query('query');
  const limit = parseInt(c.req.query('limit') || '20', 10);

  if (!query) {
    return c.json({ error: 'Query parameter is required' }, 400);
  }

  try {
    const videos = await YoutubeProvider.searchVideos(query, limit);
    return c.json({ success: true, query, totalCount: videos.length, videos });
  } catch (e: any) {
    return c.json({ error: 'Video search failed', details: e.message }, 500);
  }
});

// Trending Videos Route for Dedicated Videos Tab
app.get('/api/v1/videos/trending', async (c) => {
  const limit = parseInt(c.req.query('limit') || '20', 10);

  try {
    const videos = await YoutubeProvider.getTrendingVideos(limit);
    return c.json({ success: true, totalCount: videos.length, videos });
  } catch (e: any) {
    return c.json({ error: 'Trending videos fetch failed', details: e.message }, 500);
  }
});

// Stream URL Resolution Route
app.get('/api/v1/stream', async (c) => {
  const id = c.req.query('id');
  const encUrl = c.req.query('encryptedUrl');
  const title = c.req.query('title');
  const artist = c.req.query('artist');

  if (!id && !encUrl && (!title || !artist)) {
    return c.json({ error: 'Either id, encryptedUrl, or title+artist is required' }, 400);
  }

  try {
    // 1. Direct JioSaavn encrypted URL decryption
    if (encUrl && encUrl.trim()) {
      const streamUrl = SaavnProvider.decryptUrl(encUrl);
      if (streamUrl) {
        return c.json({ success: true, provider: 'saavn', streamUrl });
      }
    }

    // 2. ID-based resolution (handles saavn:123, youtube:xyz, or raw ID)
    if (id) {
      const cleanId = id.includes(':') ? id.split(':')[1] : id;

      if (id.startsWith('youtube:')) {
        const streamUrl = await YoutubeProvider.getAudioStream(cleanId);
        if (streamUrl) {
          return c.json({ success: true, provider: 'youtube', id, streamUrl, bitrate: '160kbps' });
        }
      } else if ((id.startsWith('spotify:') || id.startsWith('dz_')) && title && artist) {
        const streamUrl = await SpotifyProvider.getAudioStream(title, artist, c.env.YT_DLP_BASE_URL);
        if (streamUrl) {
          return c.json({ success: true, provider: 'chain', id, streamUrl });
        }
      } else {
        // Default: JioSaavn ID lookup (cleanId)
        const songDetails = await SaavnProvider.getDetails(cleanId);
        if (songDetails?.streamUrl) {
          return c.json({ success: true, provider: 'saavn', id, streamUrl: songDetails.streamUrl, bitrate: '320kbps' });
        }
      }
    }

    // 3. Title + Artist fallback matching
    if (title && artist) {
      const streamUrl = await SpotifyProvider.getAudioStream(title, artist, c.env.YT_DLP_BASE_URL);
      if (streamUrl) {
        return c.json({ success: true, provider: 'chain', streamUrl });
      }
    }

    return c.json({ error: 'Stream URL could not be resolved' }, 404);
  } catch (e: any) {
    return c.json({ error: 'Stream resolution failed', details: e.message }, 500);
  }
});

// Synced & Plain Lyrics Route (LrcLib -> Musixmatch Waterfall)
app.get('/api/v1/lyrics', async (c) => {
  const track = c.req.query('track');
  const artist = c.req.query('artist');
  const album = c.req.query('album');
  const duration = parseInt(c.req.query('duration') || '0', 10);

  if (!track || !artist) {
    return c.json({ error: 'track and artist parameters are required' }, 400);
  }

  const cacheKey = `lyrics:${track}:${artist}:${album || ''}:${duration}`;
  const cached = await c.env.SEARCH_CACHE.get(cacheKey, 'json');
  if (cached) {
    return c.json(cached);
  }

  try {
    // 1. Try LrcLib primary
    let lyrics = await LrcLibProvider.getLyrics(track, artist, album, duration);
    
    // 2. Fallback to Musixmatch
    if (!lyrics || (!lyrics.syncedLyrics && !lyrics.plainLyrics)) {
      const mxmResult = await MusixmatchProvider.getLyrics(track, artist, album);
      if (mxmResult) lyrics = mxmResult;
    }

    if (!lyrics) {
      return c.json({ success: false, message: 'Lyrics not found' }, 404);
    }

    const res = { success: true, lyrics };
    // Cache lyrics for 7 days
    c.executionCtx.waitUntil(c.env.SEARCH_CACHE.put(cacheKey, JSON.stringify(res), { expirationTtl: 604800 }));
    return c.json(res);
  } catch (e: any) {
    return c.json({ error: 'Lyrics fetch failed', details: e.message }, 500);
  }
});

// Image Proxy Route (Caches images at the edge via Cloudflare CDN)
app.get('/api/v1/image-proxy', async (c) => {
  const url = c.req.query('url');
  
  if (!url) {
    return c.json({ error: 'url parameter is required' }, 400);
  }

  try {
    const imageRes = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      },
    });

    if (!imageRes.ok) {
      return c.json({ error: 'Failed to fetch image' }, imageRes.status as any);
    }

    // Set aggressive cache headers to cache the binary data at the edge
    c.header('Cache-Control', 'public, max-age=31536000, immutable');
    c.header('Content-Type', imageRes.headers.get('Content-Type') || 'image/jpeg');

    return c.body(imageRes.body as any);
  } catch (e: any) {
    return c.json({ error: 'Image proxy failed', details: e.message }, 500);
  }
});

// AI Proxy Route
app.post('/api/v1/ai/action', async (c) => {
  const body = await c.req.json().catch(() => ({} as any));
  const { provider, action, payload } = body;
  
  if (!provider || !action || !payload) {
    return c.json({ error: 'Missing provider, action, or payload' }, 400);
  }

  try {
    const { handleOpenAIAction, handleClaudeAction, handleGeminiAction } = await import('./ai');
    let result: any = null;
    
    if (provider === 'chatgpt') {
      const apiKey = payload.apiKey || c.env.OPENAI_API_KEY;
      if (!apiKey) throw new Error('OPENAI_API_KEY missing');
      result = await handleOpenAIAction(apiKey, action, payload);
    } else if (provider === 'claude') {
      const apiKey = payload.apiKey || c.env.ANTHROPIC_API_KEY;
      if (!apiKey) throw new Error('ANTHROPIC_API_KEY missing');
      result = await handleClaudeAction(apiKey, action, payload);
    } else if (provider === 'gemini') {
      const apiKey = payload.apiKey || c.env.GEMINI_API_KEY;
      if (!apiKey) throw new Error('GEMINI_API_KEY missing');
      result = await handleGeminiAction(apiKey, action, payload);
    } else {
      throw new Error('Unsupported provider');
    }
    
    return c.json({ success: true, result });
  } catch (e: any) {
    return c.json({ success: false, error: e.message }, 500);
  }
});

// Welcome Email Route (via Resend)
app.post('/api/v1/email/welcome', async (c) => {
  const body = await c.req.json().catch(() => ({} as any));
  const { email } = body;
  
  if (!email) {
    return c.json({ error: 'Missing email address' }, 400);
  }

  const apiKey = c.env.RESEND_API_KEY;
  if (!apiKey) {
    return c.json({ error: 'Resend API key not configured on server' }, 500);
  }

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'IT Feels <noreply@itfeels.in>',
        to: email,
        subject: '🎧 You passed the vibe check. Welcome to IT Feels!',
        html: `
          <div style="font-family: sans-serif; color: #333; line-height: 1.6;">
            <h2>Hey there,</h2>
            <p>We see you. You've got good taste.</p>
            <p>Your account is officially locked in, which means your playlists are safe, your vibe is secure, and the cloud sync is ready to roll.</p>
            <p>Welcome to <strong>IT Feels</strong>. Turn the volume up.</p>
            <br/>
            <p>Keep it playing,<br/><strong>The IT Feels Team ✌️</strong></p>
          </div>
        `,
      }),
    });

    if (!res.ok) {
      const errorText = await res.text();
      throw new Error(`Resend API error: ${res.status} ${errorText}`);
    }

    const data = await res.json();
    return c.json({ success: true, data });
  } catch (e: any) {
    return c.json({ success: false, error: e.message }, 500);
  }
});

// Telemetry Play Event Route
app.post('/api/v1/telemetry/play', async (c) => {
  const body = await c.req.json().catch(() => ({} as any));
  const { songId, title, artist, coverArt } = body;
  
  if (!songId) return c.json({ error: 'Missing songId' }, 400);

  const today = new Date().toISOString().split('T')[0];
  const chartKey = `chart:${today}`;

  c.executionCtx.waitUntil((async () => {
    let chart = await c.env.SEARCH_CACHE.get(chartKey, 'json') as any || {};
    if (!chart[songId]) {
      chart[songId] = { count: 0, title, artist, coverArt };
    }
    chart[songId].count += 1;
    await c.env.SEARCH_CACHE.put(chartKey, JSON.stringify(chart), { expirationTtl: 86400 * 7 });
  })());

  return c.json({ success: true });
});

// Telemetry Trending Charts Route (48h Rolling Window)
app.get('/api/v1/charts/trending', async (c) => {
  const now = new Date();
  const today = now.toISOString().split('T')[0];
  const yesterday = new Date(now.getTime() - 86400000).toISOString().split('T')[0];

  const [chartToday, chartYesterday] = await Promise.all([
    c.env.SEARCH_CACHE.get(`chart:${today}`, 'json') as Promise<any>,
    c.env.SEARCH_CACHE.get(`chart:${yesterday}`, 'json') as Promise<any>,
  ]);

  const combinedMap: Record<string, any> = {};

  const mergeMap = (m: Record<string, any> | null, weight: number) => {
    if (!m) return;
    for (const [id, data] of Object.entries(m)) {
      if (!combinedMap[id]) {
        combinedMap[id] = { id, title: data.title, artist: data.artist, coverArt: data.coverArt, count: 0 };
      }
      combinedMap[id].count += Math.round((data.count || 0) * weight);
    }
  };

  mergeMap(chartToday, 1.0);
  mergeMap(chartYesterday, 0.5);

  const trending = Object.values(combinedMap)
    .sort((a, b) => b.count - a.count)
    .slice(0, 50);

  return c.json({ success: true, trending });
});


// Smart Edge Recommendations Route (KV Cached)
app.get('/api/v1/recommendations', async (c) => {
  const songId = c.req.query('songId');
  const artist = c.req.query('artist');

  if (!songId && !artist) {
    return c.json({ error: 'Either songId or artist parameter is required' }, 400);
  }

  const cacheKey = `recommendations:${songId || ''}:${artist || ''}`;
  const cached = await c.env.SEARCH_CACHE.get(cacheKey, 'json');
  if (cached) {
    return c.json(cached);
  }

  try {
    const query = artist ? `${artist} top hits` : 'popular hits';
    const results = await SaavnProvider.search(query, 1, 20);
    const filtered = results.filter((s: any) => s.id !== songId);

    const res = { success: true, recommendations: filtered };
    c.executionCtx.waitUntil(c.env.SEARCH_CACHE.put(cacheKey, JSON.stringify(res), { expirationTtl: 86400 }));
    return c.json(res);
  } catch (e: any) {
    return c.json({ error: 'Recommendations fetch failed', details: e.message }, 500);
  }
});

// Artist Edge Details Route (7-Day KV Cached)
app.get('/api/v1/artist/details', async (c) => {
  const artist = c.req.query('artist');

  if (!artist) {
    return c.json({ error: 'artist parameter is required' }, 400);
  }

  const cacheKey = `artist:${artist.toLowerCase().trim()}`;
  const cached = await c.env.SEARCH_CACHE.get(cacheKey, 'json');
  if (cached) {
    return c.json(cached);
  }

  try {
    const results = await SaavnProvider.search(artist, 1, 20);
    const res = { success: true, artist, topTracks: results };
    c.executionCtx.waitUntil(c.env.SEARCH_CACHE.put(cacheKey, JSON.stringify(res), { expirationTtl: 604800 }));
    return c.json(res);
  } catch (e: any) {
    return c.json({ error: 'Artist details fetch failed', details: e.message }, 500);
  }
});


// Dedicated Saavn API Suite: Home Launch Data
app.get('/api/v1/saavn/home', async (c) => {
  const cacheKey = 'saavn:home';
  const cached = await c.env.SEARCH_CACHE.get(cacheKey, 'json');
  if (cached) return c.json(cached);

  try {
    const data = await SaavnProvider.getHomePage();
    const res = { success: true, data };
    c.executionCtx.waitUntil(c.env.SEARCH_CACHE.put(cacheKey, JSON.stringify(res), { expirationTtl: 43200 }));
    return c.json(res);
  } catch (e: any) {
    return c.json({ error: 'Saavn home fetch failed', details: (e as Error).message }, 500);
  }
});

// Dedicated Saavn API Suite: Playlist Details
app.get('/api/v1/saavn/playlist', async (c) => {
  const id = c.req.query('id');
  if (!id) return c.json({ error: 'id parameter is required' }, 400);

  const cacheKey = `saavn:playlist:${id}`;
  const cached = await c.env.SEARCH_CACHE.get(cacheKey, 'json');
  if (cached) return c.json(cached);

  try {
    const playlist = await SaavnProvider.getPlaylist(id);
    const res = { success: true, playlist };
    c.executionCtx.waitUntil(c.env.SEARCH_CACHE.put(cacheKey, JSON.stringify(res), { expirationTtl: 86400 }));
    return c.json(res);
  } catch (e: any) {
    return c.json({ error: 'Saavn playlist fetch failed', details: (e as Error).message }, 500);
  }
});

// Dedicated Saavn API Suite: Album Details
app.get('/api/v1/saavn/album', async (c) => {
  const id = c.req.query('id');
  if (!id) return c.json({ error: 'id parameter is required' }, 400);

  const cacheKey = `saavn:album:${id}`;
  const cached = await c.env.SEARCH_CACHE.get(cacheKey, 'json');
  if (cached) return c.json(cached);

  try {
    const album = await SaavnProvider.getAlbum(id);
    const res = { success: true, album };
    c.executionCtx.waitUntil(c.env.SEARCH_CACHE.put(cacheKey, JSON.stringify(res), { expirationTtl: 86400 }));
    return c.json(res);
  } catch (e: any) {
    return c.json({ error: 'Saavn album fetch failed', details: (e as Error).message }, 500);
  }
});

// Dedicated Saavn API Suite: Artist Details
app.get('/api/v1/saavn/artist', async (c) => {
  const id = c.req.query('id');
  if (!id) return c.json({ error: 'id parameter is required' }, 400);

  const cacheKey = `saavn:artist:${id}`;
  const cached = await c.env.SEARCH_CACHE.get(cacheKey, 'json');
  if (cached) return c.json(cached);

  try {
    const artist = await SaavnProvider.getArtist(id);
    const res = { success: true, artist };
    c.executionCtx.waitUntil(c.env.SEARCH_CACHE.put(cacheKey, JSON.stringify(res), { expirationTtl: 86400 }));
    return c.json(res);
  } catch (e: any) {
    return c.json({ error: 'Saavn artist fetch failed', details: (e as Error).message }, 500);
  }
});


// Standalone Native Custom API Routes (/api/v1/native/*)

// 1. Fetch Native Home Feed (Playlists, Trending, Imports)
app.get('/api/v1/native/home', async (c) => {
  try {
    let feed = await NativeDatabaseProvider.getHomeFeed(c.env.SEARCH_CACHE);
    
    // Background Learning Engine (JIT Home Feed Seeding)
    if (!feed.sections || feed.sections.length === 0) {
      console.log('[NativeHome] Feed empty. JIT seeding from Saavn Home...');
      const saavnHome = await SaavnProvider.getHomePage();
      
      const tracksToSeed: any[] = [];
      for (const section of saavnHome.sections || []) {
        if (section.items) {
          for (const item of section.items) {
            if (item.type === 'song' && item.streamUrl && item.streamUrl.trim() !== '') {
              tracksToSeed.push({
                id: `native:${item.id.replace('saavn:', '')}`,
                title: item.title,
                artist: item.artist,
                album: item.album || 'Unknown Album',
                albumArtUrl: item.coverArt,
                durationSeconds: item.duration || 0,
                streamUrl: item.streamUrl,
                releaseYear: (item.year || 0).toString(),
                type: 'song',
                origin: 'JIT-Home-Migration'
              });
            }
          }
        }
      }
      
      if (tracksToSeed.length > 0) {
        await NativeDatabaseProvider.addSongsBatch(c.env.SEARCH_CACHE, tracksToSeed);
        console.log(`[NativeHome] JIT Seeded ${tracksToSeed.length} tracks.`);
        feed = await NativeDatabaseProvider.getHomeFeed(c.env.SEARCH_CACHE);
      }
    }
    
    return c.json(feed);
  } catch (e: any) {
    return c.json({ error: 'Native home fetch failed', details: (e as Error).message }, 500);
  }
});

// 2. Search Custom Native Database Catalog
app.get('/api/v1/native/search', async (c) => {
  const query = c.req.query('query') || '';
  try {
    let results = await NativeDatabaseProvider.searchSongs(c.env.SEARCH_CACHE, query);
    
    // Background Learning Engine (JIT Search Seeding)
    if (results.length === 0 && query.trim() !== '') {
      console.log(`[NativeSearch] JIT Seeding for query: ${query}`);
      const saavnResults = await SaavnProvider.search(query, 1, 15);
      const tracksToSeed: any[] = [];
      
      for (const track of saavnResults) {
        if (track.streamUrl && track.streamUrl.trim() !== '') {
          tracksToSeed.push({
            id: `native:${track.id.replace('saavn:', '')}`,
            title: track.title,
            artist: track.artist,
            album: track.album || 'Unknown Album',
            albumArtUrl: track.coverArt,
            durationSeconds: track.duration || 0,
            streamUrl: track.streamUrl,
            releaseYear: (track.year || 0).toString(),
            type: 'song',
            origin: 'JIT-Search-Migration'
          });
        }
      }
      
      if (tracksToSeed.length > 0) {
        await NativeDatabaseProvider.addSongsBatch(c.env.SEARCH_CACHE, tracksToSeed);
        console.log(`[NativeSearch] JIT Seeded ${tracksToSeed.length} tracks.`);
        results = tracksToSeed; 
      }
    }

    return c.json({ success: true, query, totalCount: results.length, results });
  } catch (e: any) {
    return c.json({ error: 'Native search failed', details: (e as Error).message }, 500);
  }
});

// 3. Fetch All Native Songs Catalog
app.get('/api/v1/native/songs', async (c) => {
  try {
    const catalog = await NativeDatabaseProvider.getCatalog(c.env.SEARCH_CACHE);
    return c.json({ success: true, totalCount: catalog.length, songs: catalog });
  } catch (e: any) {
    return c.json({ error: 'Native songs fetch failed', details: (e as Error).message }, 500);
  }
});

// 4. Fetch Single Native Song by ID
app.get('/api/v1/native/songs/:id', async (c) => {
  const id = c.req.param('id');
  try {
    const catalog = await NativeDatabaseProvider.getCatalog(c.env.SEARCH_CACHE);
    const song = catalog.find((s) => s.id === id || s.id === `native:${id}`);
    if (!song) return c.json({ error: 'Song not found in native database' }, 404);
    return c.json({ success: true, song });
  } catch (e: any) {
    return c.json({ error: 'Native song details fetch failed', details: (e as Error).message }, 500);
  }
});

// 5. Create / Add New Custom Song Entry to Native Database
app.post('/api/v1/native/songs', async (c) => {
  try {
    const body = await c.req.json();
    const { title, artist, album, duration, coverArt, streamUrl } = body;
    if (!title || !artist || !streamUrl) {
      return c.json({ error: 'Missing required fields: title, artist, or streamUrl' }, 400);
    }

    const newSong = await NativeDatabaseProvider.addSong(c.env.SEARCH_CACHE, {
      title,
      artist,
      album: album || 'Single',
      duration: parseInt(duration || '180', 10),
      coverArt: coverArt || 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500',
      streamUrl,
    });

    return c.json({ success: true, song: newSong });
  } catch (e: any) {
    return c.json({ error: 'Failed to add song to native database', details: (e as Error).message }, 500);
  }
});

// 6. Saavn-to-Native Importer (Clones Saavn data into native database schema)
app.post('/api/v1/native/import/saavn', async (c) => {
  try {
    const body = await c.req.json();
    const { saavnId } = body;
    if (!saavnId) return c.json({ error: 'saavnId parameter is required' }, 400);

    const saavnTrack = await SaavnProvider.getDetails(saavnId);
    if (!saavnTrack || !saavnTrack.streamUrl) {
      return c.json({ error: 'Could not fetch or decrypt track from Saavn' }, 404);
    }

    const nativeSong = await NativeDatabaseProvider.addSong(c.env.SEARCH_CACHE, {
      id: `native:${saavnTrack.id.replace('saavn:', '')}`,
      title: saavnTrack.title,
      artist: saavnTrack.artist,
      album: saavnTrack.album,
      duration: saavnTrack.duration,
      coverArt: saavnTrack.coverArt,
      streamUrl: saavnTrack.streamUrl,
      hasLyrics: saavnTrack.hasLyrics,
      language: saavnTrack.language,
      year: saavnTrack.year,
      explicit: saavnTrack.explicit,
    });

    return c.json({
      success: true,
      message: 'Successfully imported Saavn track into Native Database schema!',
      song: nativeSong,
    });
  } catch (e: any) {
    return c.json({ error: 'Saavn import failed', details: (e as Error).message }, 500);
  }
});


// 7. Saavn Batch Seeder (HTTP Manual Trigger from GitHub Harvester Bot)
app.post('/api/v1/native/seed/saavn', async (c) => {
  try {
    const body = await c.req.json().catch(() => ({}));
    const queries: string[] = body.queries || ['Trending Hits', 'Top Hindi Hits', 'Global Pop', 'Arijit Singh', 'Taylor Swift'];
    const limitPerQuery = parseInt(body.limitPerQuery || '10', 10);

    const allTracksToInsert: any[] = [];

    for (const query of queries) {
      try {
        const saavnResults = await SaavnProvider.search(query, 1, limitPerQuery);
        for (const track of saavnResults) {
          if (track.streamUrl && track.streamUrl.trim() !== '') {
            allTracksToInsert.push({
              id: `native:${track.id.replace('saavn:', '')}`,
              title: track.title,
              artist: track.artist,
              album: track.album,
              duration: track.duration,
              coverArt: track.coverArt,
              streamUrl: track.streamUrl,
              hasLyrics: track.hasLyrics,
              language: track.language,
              year: track.year,
              explicit: track.explicit,
            });
          }
        }
      } catch (e) {
        console.error(`Failed to fetch query "${query}" during Saavn seed:`, e);
      }
    }

    const result = await NativeDatabaseProvider.addSongsBatch(c.env.SEARCH_CACHE, allTracksToInsert);

    return c.json({
      success: true,
      message: `Successfully batch seeded Saavn library into Native Database!`,
      importedCount: result.addedCount,
      totalCatalogSize: result.totalCount,
    });
  } catch (e: any) {
    return c.json({ error: 'Saavn batch seed failed', details: (e as Error).message }, 500);
  }
});

export default app;
