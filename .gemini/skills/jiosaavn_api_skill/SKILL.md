---
name: jiosaavn-api-skill
description: Comprehensive specifications for JioSaavn API endpoints, DES-ECB link decryption, 320kbps audio upgrade, and LRCLIB synchronized lyrics fetching.
---

# JioSaavn API & Audio Stream Integration Skill Guide

## 1. Overview
This skill provides exact technical specs for interacting with JioSaavn's public web API and LRCLIB for synchronized lyrics.

## 2. API Endpoints

### Base URL
`https://www.jiosaavn.com/api.php`

### Common Parameters
- `_format`: `json`
- `_marker`: `0`
- `api_version`: `4`
- `ctx`: `web6dot0`

---

### Endpoints Detail

#### 1. Search / Autocomplete
- **Call**: `autocomplete.get` or `search.getResults`
- **URL**: `https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0&api_version=4&ctx=web6dot0&query={QUERY}`
- **Returns**: Object with `songs.data`, `albums.data`, `playlists.data`, `artists.data`.

#### 2. Homepage & Trending Content
- **Call**: `content.getHomepageData`
- **URL**: `https://www.jiosaavn.com/api.php?__call=content.getHomepageData&_format=json&_marker=0&api_version=4&ctx=web6dot0`
- **Returns**: `charts`, `new_albums`, `top_playlists`, `featured_playlists`.

#### 3. Playlist / Album Details
- **Call**: `playlist.getDetails` (for playlists) or `content.getAlbumDetails` (for albums)
- **URL**: `https://www.jiosaavn.com/api.php?__call=playlist.getDetails&_format=json&cc=in&_marker=0&api_version=4&ctx=web6dot0&listid={LIST_ID}`

#### 4. Song Details & Encrypted Stream URL
- **Call**: `song.getDetails`
- **URL**: `https://www.jiosaavn.com/api.php?__call=song.getDetails&_format=json&cc=in&_marker=0&pids={SONG_ID}`
- **Key Field**: `encrypted_media_url`

---

## 3. Stream URL Decryption & 320kbps Quality Upgrade

### Decryption Algorithm
- **Cipher**: DES-ECB
- **Key**: `38346591`
- **IV**: `00000000` (8 zero bytes)

### Decryption Steps in Dart/Flutter:
1. Base64 decode `encrypted_media_url`.
2. Decrypt with DES-ECB using key `'38346591'`.
3. Trim PKCS7 padding to get plaintext CDN URL (typically 96kbps preview URL).

### Quality Upgrade Algorithm:
```dart
String upgradeTo320kbps(String decryptedUrl) {
  if (decryptedUrl.contains('preview.saavncdn.com')) {
    return decryptedUrl
        .replaceAll(RegExp(r'(_96_p|_96|_160)\.(mp3|m4a)$'), '_320.mp4')
        .replaceAll('preview.saavncdn.com', 'aac.saavncdn.com');
  }
  return decryptedUrl.replaceAll(RegExp(r'(_96_p|_96|_160)\.(mp3|m4a)$'), '_320.mp4');
}
```

---

## 4. Synchronized Lyrics Integration

### Strategy
1. **Primary**: Fetch JioSaavn static lyrics via `lyrics.getLyrics` API (`lyrics_id={SONG_ID}`).
2. **Synced Fallback**: Query LRCLIB search API `https://lrclib.net/api/search?q={ARTIST}+{TITLE}`.
3. Parse `.lrc` format timestamps (`[mm:ss.xx] Lyric line text`) into structured data objects for animated UI autoscroll.
