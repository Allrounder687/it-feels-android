/**
 * IT-Feels Edge Shield Proxy
 * 
 * Deploy this script to your Cloudflare Worker.
 * It expects a KV Namespace bound to the variable `STREAM_CACHE`.
 * 
 * This endpoint: GET /api/v1/videos/streams?videoId=...
 */

const PIPED_INSTANCES = [
  'https://pipedapi.moomoo.me',
  'https://pipedapi.syncpundit.io',
  'https://piapi.ggtyler.dev',
  'https://api.piped.private.coffee',
  'https://pipedapi.kavin.rocks',
];

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    
    // Authenticate (Basic shared secret)
    const secret = request.headers.get('X-Feels-Secret');
    if (secret !== env.API_SECRET) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
    }

    if (url.pathname === '/api/v1/videos/streams' && request.method === 'GET') {
      const videoId = url.searchParams.get('videoId');
      if (!videoId) return new Response(JSON.stringify({ error: "Missing videoId" }), { status: 400 });

      // 1. Check KV Cache (Raw URLs expire fast, keep TTL low, e.g. 3-4 hours)
      const cacheKey = `stream_${videoId}`;
      const cached = await env.STREAM_CACHE.get(cacheKey, { type: "json" });
      if (cached) {
        return new Response(JSON.stringify({ success: true, fromCache: true, ...cached }), {
          headers: { 'Content-Type': 'application/json' }
        });
      }

      // 2. Race multiple Piped instances in parallel
      try {
        const result = await Promise.any(
          PIPED_INSTANCES.map(instance => fetchPipedStream(instance, videoId))
        );

        if (result && result.streams.length > 0) {
          // Cache the successful result for 3 hours (10800 seconds)
          // googlevideo.com URLs strictly expire after 6 hours.
          await env.STREAM_CACHE.put(cacheKey, JSON.stringify(result), { expirationTtl: 10800 });

          return new Response(JSON.stringify({ success: true, fromCache: false, ...result }), {
            headers: { 'Content-Type': 'application/json' }
          });
        }
      } catch (err) {
        // Promise.any throws AggregateError if all promises fail
        return new Response(JSON.stringify({ success: false, error: "All edge extraction nodes failed" }), { status: 502 });
      }
    }

    // Default 404
    return new Response(JSON.stringify({ error: "Not found" }), { status: 404 });
  }
};

async function fetchPipedStream(instanceUrl, videoId) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 3500); // Fast timeout for racing

  try {
    const res = await fetch(`${instanceUrl}/streams/${videoId}`, { signal: controller.signal });
    if (!res.ok) throw new Error("Bad status");
    
    const data = await res.json();
    clearTimeout(timeout);

    const streams = [];
    const uniqueQualities = new Set();
    
    // Parse video streams
    for (const s of (data.videoStreams || [])) {
      let q = s.quality || (s.height ? `${s.height}p` : null);
      if (q && s.url) {
        if (q.toLowerCase() === 'high') q = '1080p';
        if (q.toLowerCase() === 'medium') q = '720p';
        if (q.toLowerCase() === 'low') q = '360p';
        
        const match = q.match(/\d+/);
        const formattedQuality = match ? `${match[0]}p` : (q.includes('p') ? q : `${q}p`);

        if (!uniqueQualities.has(formattedQuality)) {
          uniqueQualities.add(formattedQuality);
          streams.push({
            quality: formattedQuality,
            url: s.url,
            mimeType: s.mimeType || '',
            videoOnly: s.videoOnly || false,
          });
        }
      }
    }

    const audioUrl = data.audioStreams && data.audioStreams.length > 0 ? data.audioStreams[0].url : '';

    if (streams.length > 0 || audioUrl) {
      return {
        title: data.title || 'Music Video',
        durationMs: (data.duration || 0) * 1000,
        streams,
        audioUrl,
      };
    }
    throw new Error("No streams found");
  } catch (e) {
    clearTimeout(timeout);
    throw e;
  }
}
