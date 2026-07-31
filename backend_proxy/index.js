const express = require('express');
const cors = require('cors');
const youtubedl = require('youtube-dl-exec');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());

// Health check endpoint
app.get('/', (req, res) => {
  res.json({ status: 'ok', service: 'it-feels-yt-proxy' });
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.get('/api/streams', async (req, res) => {
  const { videoId } = req.query;
  
  if (!videoId) {
    return res.status(400).json({ error: 'videoId is required' });
  }

  try {
    const url = `https://www.youtube.com/watch?v=${videoId}`;
    console.log(`Fetching streams for ${videoId}...`);

    const output = await youtubedl(url, {
      dumpJson: true,
      noWarnings: true,
      preferFreeFormats: true,
      youtubeSkipDashManifest: true,
      // Force extraction through a supported player client so we avoid
      // PO-token / unsupported-browser failures on Render.
      extractorArgs: 'youtube:player_client=ios,tvhtml5',
      // Prefer a container that is widely playable on the mobile client.
      mergeOutputFormat: 'mp4',
      forceIpv4: true,
      socketTimeout: 30,
    });
    
    // Process formats
    const uniqueQualities = {};
    const audioStreams = [];

    if (output.formats) {
      output.formats.forEach(f => {
        // Collect high quality audio streams so we have a fallback for video-only DASH streams
        if (f.acodec !== 'none' && f.vcodec === 'none') {
          audioStreams.push(f);
          return; // Skip adding this to the video qualities list
        }

        const height = f.height || parseInt((f.format_note || '0').replace(/[^0-9]/g, '')) || 0;
        const is4K = String(height).startsWith('216') || String(height).startsWith('384') || /2160p/.test(f.format_note || '');
        const is2K = String(height).startsWith('144') || String(height).startsWith('256') || /1440p/.test(f.format_note || '');
        const is1080 = String(height).startsWith('108') || /1080p/.test(f.format_note || '');

        let quality = '360p';
        if (is4K) quality = '2160p (4K)';
        else if (is2K) quality = '1440p (2K)';
        else if (is1080) quality = '1080p';
        else if (height >= 720) quality = '720p';
        else if (height >= 480) quality = '480p';

        // Prefer muxed (audio+video) or higher bitrate for same quality
        const isMuxed = f.acodec !== 'none' && f.vcodec !== 'none';
        const tbr = f.tbr || 0;

        if (!uniqueQualities[quality] || (isMuxed && !uniqueQualities[quality].hasAudio)) {
          uniqueQualities[quality] = {
            quality,
            url: f.url,
            hasAudio: isMuxed,
            vcodec: f.vcodec,
            tbr,
            container: f.ext,
          };
        }
      });
    }

    // Sort audio by bitrate
    audioStreams.sort((a, b) => (b.abr || 0) - (a.abr || 0));
    const bestAudio = audioStreams.length > 0 ? audioStreams[0].url : '';
    
    res.json({
      title: output.title,
      streams: Object.values(uniqueQualities).sort((a, b) => (b.tbr || 0) - (a.tbr || 0)),
      audioUrl: bestAudio
    });
    
  } catch (error) {
    console.error('Error fetching streams:', error);
    res.status(500).json({ error: 'Failed to extract streams' });
  }
});

app.listen(port, () => {
  console.log(`IT Feels YT Proxy listening at port ${port}`);
});
