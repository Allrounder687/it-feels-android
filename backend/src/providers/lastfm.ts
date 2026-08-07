import MD5 from 'crypto-js/md5';

export class LastfmProvider {
  private static BASE_URL = 'https://ws.audioscrobbler.com/2.0/';

  private generateSignature(params: Record<string, string>, sharedSecret: string): string {
    const sortedKeys = Object.keys(params).sort();
    let buffer = '';

    for (const key of sortedKeys) {
      if (key !== 'format' && key !== 'callback') {
        buffer += `${key}${params[key]}`;
      }
    }

    buffer += sharedSecret;
    return MD5(buffer).toString();
  }

  async authenticate(username: string, password: string, apiKey: string, sharedSecret: string) {
    const params: Record<string, string> = {
      method: 'auth.getMobileSession',
      username,
      password,
      api_key: apiKey,
    };

    params['api_sig'] = this.generateSignature(params, sharedSecret);
    params['format'] = 'json';

    const formBody = new URLSearchParams(params).toString();

    const res = await fetch(LastfmProvider.BASE_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: formBody,
    });

    const data = await res.json() as any;

    if (!res.ok) {
      throw new Error(data.message || 'Failed to authenticate');
    }

    return {
      sessionKey: data.session.key,
      name: data.session.name,
    };
  }

  async updateNowPlaying(sessionKey: string, track: string, artist: string, apiKey: string, sharedSecret: string, album?: string) {
    const params: Record<string, string> = {
      method: 'track.updateNowPlaying',
      track,
      artist,
      api_key: apiKey,
      sk: sessionKey,
    };

    if (album) {
      params['album'] = album;
    }

    params['api_sig'] = this.generateSignature(params, sharedSecret);
    params['format'] = 'json';

    const formBody = new URLSearchParams(params).toString();

    const res = await fetch(LastfmProvider.BASE_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: formBody,
    });

    if (!res.ok) {
      const data = await res.json() as any;
      throw new Error(data.message || 'Failed to update now playing');
    }

    return await res.json();
  }

  async scrobble(sessionKey: string, track: string, artist: string, timestamp: string, apiKey: string, sharedSecret: string, album?: string) {
    const params: Record<string, string> = {
      method: 'track.scrobble',
      track,
      artist,
      timestamp,
      api_key: apiKey,
      sk: sessionKey,
    };

    if (album) {
      params['album'] = album;
    }

    params['api_sig'] = this.generateSignature(params, sharedSecret);
    params['format'] = 'json';

    const formBody = new URLSearchParams(params).toString();

    const res = await fetch(LastfmProvider.BASE_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: formBody,
    });

    if (!res.ok) {
      const data = await res.json() as any;
      throw new Error(data.message || 'Failed to scrobble');
    }

    return await res.json();
  }
}
