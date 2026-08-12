import { Hono } from 'hono';
import { SaavnProvider } from './providers/saavn';
import { YoutubeProvider } from './providers/youtube';

export const telegram = new Hono<{ Bindings: any }>();

const getSmartAdvert = () => `
🚀 **Want the full experience?** Stop downloading individual tracks! Get our app for Ad-Free High-Quality Streaming, Live Rooms, Synced Lyrics, and Background Video Playback.

⬇️ [Download for Windows](https://github.com/Allrounder687/it-feels-android/releases/latest) | ⬇️ [Download for Android](https://github.com/Allrounder687/it-feels-android/releases/latest)
`;

telegram.post('/webhook', async (c) => {
  try {
    const token = c.env.TELEGRAM_BOT_TOKEN;
    if (!token) {
      return c.json({ error: 'Missing TELEGRAM_BOT_TOKEN' }, 500);
    }

    const body = await c.req.json();

    // 1. Handle Callback Queries (Button Presses)
    if (body.callback_query) {
      const callbackId = body.callback_query.id;
      const data = body.callback_query.data;
      const message = body.callback_query.message;
      const chatId = message.chat.id;

      const parts = data.split('_');
      const cmd = parts[0];

      if (cmd === 'qa') {
        const saavnId = parts.slice(1).join('_');
        return c.json({
          method: 'editMessageText',
          chat_id: chatId,
          message_id: message.message_id,
          text: `🎵 **Select Audio Quality**\n\nChoose the download quality for your track:`,
          parse_mode: 'Markdown',
          reply_markup: {
            inline_keyboard: [
              [
                { text: '⚡ Standard (Fast)', callback_data: `da_128_${saavnId}` },
                { text: '🎧 Premium (320kbps)', callback_data: `da_320_${saavnId}` }
              ]
            ]
          }
        });
      }

      if (cmd === 'qv') {
        const ytId = parts.slice(1).join('_');
        const baseUrl = 'https://it-feels-proxy.cleverfox687.workers.dev/telegram/download';
        
        return c.json({
          method: 'editMessageText',
          chat_id: chatId,
          message_id: message.message_id,
          text: `🎥 **Video Selected**\n\nChoose an option below:\n\n*Note: High-quality downloads open in your browser to show a progress bar and bypass Telegram's 20MB limit.*`,
          parse_mode: 'Markdown',
          reply_markup: {
            inline_keyboard: [
              [
                { 
                  text: '📺 Stream in Telegram', 
                  web_app: { url: `https://it-feels-proxy.cleverfox687.workers.dev/telegram/player?id=${ytId.replace('youtube:', '')}` } 
                }
              ],
              [
                { text: '⬇️ Download 360p', url: `${baseUrl}?id=${ytId.replace('youtube:', '')}&quality=360p` },
                { text: '⬇️ Download 720p', url: `${baseUrl}?id=${ytId.replace('youtube:', '')}&quality=720p` },
                { text: '⬇️ Download 4K', url: `${baseUrl}?id=${ytId.replace('youtube:', '')}&quality=2160p` }
              ]
            ]
          }
        });
      }

      if (cmd === 'da') {
        const quality = parts[1];
        const saavnId = parts.slice(2).join('_');
        
        const track = await SaavnProvider.getDetails(saavnId);
        if (track && track.streamUrl) {
          c.executionCtx.waitUntil((async () => {
            try {
              const res = await fetch(`https://api.telegram.org/bot${token}/sendAudio`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                  chat_id: chatId,
                  audio: track.streamUrl,
                  title: track.title,
                  performer: track.artist,
                  caption: `🎵 **${track.title}**\n\n${getSmartAdvert()}`,
                  parse_mode: 'Markdown'
                })
              });
              const text = await res.text();
              console.log('Telegram sendAudio response:', text);
            } catch (e) {
              console.error('Telegram sendAudio failed:', e);
            }
          })());

          return c.json({
            method: 'editMessageText',
            chat_id: chatId,
            message_id: message.message_id,
            text: `✅ **Sending "${track.title}"...**\nCheck your chat below! 👇`,
            parse_mode: 'Markdown'
          });
        }
      }

      return c.json({ method: 'answerCallbackQuery', callback_query_id: callbackId });
    }

    // 2. Handle Inline Queries (Viral mode)
    if (body.inline_query) {
      const queryId = body.inline_query.id;
      const queryStr = body.inline_query.query.trim();

      if (!queryStr) {
        return c.json({ method: 'answerInlineQuery', inline_query_id: queryId, results: [] });
      }

      const results: any[] = [];
      let isVideo = false;
      let searchQuery = queryStr;

      if (queryStr.toLowerCase().startsWith('/video ')) {
        isVideo = true;
        searchQuery = queryStr.substring(7).trim();
      }

      if (isVideo) {
        const ytResults = await YoutubeProvider.search(searchQuery, c.env.YT_DLP_BASE_URL);
        if (ytResults && ytResults.length > 0) {
          const topResult = ytResults[0];
          results.push({
            type: 'video',
            id: topResult.id,
            video_url: topResult.streamUrl || `https://it-feels-android.onrender.com/stream?id=${topResult.id.replace('youtube:', '')}`,
            mime_type: 'video/mp4',
            thumb_url: topResult.coverArt,
            title: topResult.title,
            description: topResult.artist,
            caption: `🎥 **${topResult.title}**\n*Downloaded via @ItFeelsMusicBot*\n\n${getSmartAdvert()}`,
            parse_mode: 'Markdown'
          });
        }
      } else {
        const saavnResults = await SaavnProvider.search(searchQuery, 1, 5);
        if (saavnResults && saavnResults.length > 0) {
          for (let i = 0; i < Math.min(saavnResults.length, 3); i++) {
            const track = saavnResults[i];
            if (track.streamUrl) {
              results.push({
                type: 'audio',
                id: track.id,
                audio_url: track.streamUrl,
                title: track.title,
                performer: track.artist,
                caption: `🎵 **${track.title}**\n*Downloaded via @ItFeelsMusicBot*\n\n${getSmartAdvert()}`,
                parse_mode: 'Markdown'
              });
            }
          }
        }
      }

      return c.json({
        method: 'answerInlineQuery',
        inline_query_id: queryId,
        results: results
      });
    }

    // 3. Handle Standard Messages (Zero Cognitive Overload Universal Search)
    if (body.message && body.message.text) {
      const chatId = body.message.chat.id;
      const text = body.message.text.trim();

      if (text.startsWith('/start')) {
        return c.json({
          method: 'sendMessage',
          chat_id: chatId,
          text: `👋 **Welcome to IT-Feels Music Bot!**\n\nI can instantly send you any Song or Music Video. You can stream it directly here in the chat!\n\nJust type the name of a song or artist right here (e.g. "Starboy The Weeknd").`,
          parse_mode: 'Markdown'
        });
      }

      const [saavnResults, ytResults] = await Promise.all([
        SaavnProvider.search(text, 1, 2),
        YoutubeProvider.search(text, c.env.YT_DLP_BASE_URL)
      ]);

      const inline_keyboard: any[][] = [];

      if (saavnResults && saavnResults.length > 0) {
        for (let i = 0; i < Math.min(saavnResults.length, 2); i++) {
          const track = saavnResults[i];
          const rawId = track.id.replace('saavn:', '');
          inline_keyboard.push([{ text: `🎵 ${track.title} - ${track.artist}`, callback_data: `qa_${rawId}` }]);
        }
      }

      if (ytResults && ytResults.length > 0) {
        for (let i = 0; i < Math.min(ytResults.length, 2); i++) {
          const track = ytResults[i];
          const rawId = track.id.replace('youtube:', '');
          inline_keyboard.push([{ text: `🎥 ${track.title}`, callback_data: `qv_${rawId}` }]);
        }
      }

      if (inline_keyboard.length === 0) {
        return c.json({
          method: 'sendMessage',
          chat_id: chatId,
          text: `❌ Could not find any results for "${text}". Try another search!`,
          parse_mode: 'Markdown'
        });
      }

      return c.json({
        method: 'sendMessage',
        chat_id: chatId,
        text: `🔍 **Results for "${text}"**\nSelect what you want to play:`,
        parse_mode: 'Markdown',
        reply_markup: { inline_keyboard }
      });
    }

    return c.json({ status: 'ignored' });
  } catch (error) {
    console.error('Telegram Webhook Error:', error);
    return c.json({ error: 'Internal Server Error' }, 500);
  }
});

// Telegram Mini-App Player Route (Resilient Player)
telegram.get('/player', (c) => {
  const id = c.req.query('id');
  if (!id) return c.html('Missing Video ID', 400);

  return c.html(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <title>IT-Feels Mini Player</title>
      <script src="https://telegram.org/js/telegram-web-app.js"></script>
      <style>
        body {
          margin: 0;
          padding: 0;
          background-color: var(--tg-theme-bg-color, #0f0f13);
          color: var(--tg-theme-text-color, #ffffff);
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          display: flex;
          flex-direction: column;
          height: 100vh;
          overflow: hidden;
        }
        .video-container {
          width: 100%;
          background: #000;
          display: flex;
          justify-content: center;
          align-items: center;
          box-shadow: 0 4px 20px rgba(0,0,0,0.5);
          min-height: 250px;
          position: relative;
        }
        video {
          width: 100%;
          max-height: 50vh;
        }
        #loading {
          position: absolute;
          color: white;
          font-weight: bold;
        }
        .info {
          padding: 20px;
          text-align: center;
          flex: 1;
        }
        h2 {
          margin: 0 0 10px 0;
          font-size: 1.2rem;
        }
        .badge {
          display: inline-block;
          background: #ff3b30;
          color: white;
          padding: 4px 8px;
          border-radius: 12px;
          font-size: 0.8rem;
          font-weight: bold;
          margin-bottom: 20px;
        }
        .advert {
          background: rgba(255,255,255,0.05);
          padding: 15px;
          border-radius: 12px;
          font-size: 0.9rem;
          line-height: 1.4;
          margin-top: auto;
          border: 1px solid rgba(255,255,255,0.1);
        }
        .btn {
          display: block;
          background: var(--tg-theme-button-color, #ff3b30);
          color: var(--tg-theme-button-text-color, #fff);
          text-decoration: none;
          padding: 12px;
          border-radius: 10px;
          font-weight: bold;
          margin-top: 15px;
        }
      </style>
    </head>
    <body>
      <div class="video-container">
        <div id="loading">Resolving 4K Stream...</div>
        <video id="vid" controls autoplay playsinline style="display:none;"></video>
      </div>
      <div class="info">
        <h2 id="vtitle">IT-Feels Stream</h2>
        <div class="badge">4K ULTRA HD</div>
        
        <div class="advert">
          🚀 <strong>Tired of bots?</strong><br>
          Get the full IT-Feels Music app for ad-free high-quality streaming, synced lyrics, and offline downloads!
          <a href="https://github.com/Allrounder687/it-feels-android/releases/latest" class="btn" target="_blank">Download App</a>
        </div>
      </div>
      <script>
        // Initialize Telegram Web App
        window.Telegram.WebApp.ready();
        window.Telegram.WebApp.expand();

        // Fetch resilient stream URL from our Cloudflare backend
        fetch('/api/v1/video?id=${id}')
          .then(res => res.json())
          .then(data => {
            if (data.success && data.streams && data.streams.length > 0) {
              document.getElementById('loading').style.display = 'none';
              document.getElementById('vtitle').innerText = data.title;
              const vid = document.getElementById('vid');
              vid.style.display = 'block';
              
              // Pick highest quality stream available (usually 720p or 4K from yt-dlp)
              let bestStream = data.streams[0].url;
              vid.src = bestStream;
            } else {
              document.getElementById('loading').innerText = 'Stream unavailable.';
            }
          })
          .catch(err => {
             document.getElementById('loading').innerText = 'Network error.';
          });
      </script>
    </body>
    </html>
  `);
});

// Resilient Direct Download Redirector
telegram.get('/download', async (c) => {
  const id = c.req.query('id');
  const qualityParam = c.req.query('quality') || '720p'; // e.g. 360p, 720p, 1080p, 2160p

  if (!id) return c.text('Missing Video ID', 400);

  try {
    // 1. Fetch from our backend to resolve via Render -> Piped -> InnerTube
    // We do a local fetch to our own worker to utilize the same logic
    const proto = c.req.header('x-forwarded-proto') || 'https';
    const host = c.req.header('host');
    const apiUrl = `${proto}://${host}/api/v1/video?id=${id}`;

    const res = await fetch(apiUrl);
    if (!res.ok) {
      return c.text('Failed to resolve video stream', 500);
    }
    
    const data = await res.json() as any;
    if (data.success && data.streams && data.streams.length > 0) {
      // 2. Find matching quality stream, or fallback to highest available
      let streamUrl = data.streams[0].url;
      const match = data.streams.find((s: any) => s.quality === qualityParam || (s.quality && s.quality.includes(qualityParam.replace('p', ''))));
      if (match) {
        streamUrl = match.url;
      }
      
      // 3. Issue HTTP 302 Redirect directly to googlevideo.com
      // The browser natively downloads the raw mp4!
      return c.redirect(streamUrl, 302);
    } else {
      return c.text('No streams found for this video', 404);
    }
  } catch (err) {
    return c.text('Internal Server Error', 500);
  }
});
