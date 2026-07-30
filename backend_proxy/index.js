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
      noCheckCertificate: true,
      preferFreeFormats: true,
      youtubeSkipDashManifest: true,
      impersonate: 'chrome',
      socketTimeout: 30, // Prevent infinite network hanging
    });
    
    // Process formats
    const uniqueQualities = {};
    const audioStreams = [];
    
    if (output.formats) {
      output.formats.forEach(f => {
        // Collect high quality audio
        if (f.acodec !== 'none' && f.vcodec === 'none') {
          audioStreams.push(f);
        }
        
        // Collect MP4 video streams
        if (f.ext === 'mp4' && f.vcodec !== 'none') {
          let quality = f.format_note || f.height + 'p';
          if (!quality.includes('p')) quality = quality + 'p';
          
          if (quality.includes('2160')) quality = '2160p (4K)';
          else if (quality.includes('1440')) quality = '1440p (2K)';
          
          // Prefer higher bitrate or muxed if same quality
          if (!uniqueQualities[quality] || (f.acodec !== 'none' && uniqueQualities[quality].hasAudio === false)) {
            uniqueQualities[quality] = {
              quality: quality,
              url: f.url,
              hasAudio: f.acodec !== 'none',
              vcodec: f.vcodec,
              tbr: f.tbr
            };
          }
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
