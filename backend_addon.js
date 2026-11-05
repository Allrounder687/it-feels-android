const PROXY_URL = "https://it-feels-proxy.cleverfox687.workers.dev";
const BACKEND_URL = "https://it-feels-backend.cleverfox687.workers.dev";

// Return the direct search API endpoint (Multi-source: Saavn, YouTube, Spotify)
function getSearchUrl(query) {
    return PROXY_URL + "/api/v1/search?query=" + encodeURIComponent(query);
}

// Return the direct playlist search endpoint
function getSearchPlaylistsUrl(query) {
    return BACKEND_URL + "/api/v1/search/playlists?query=" + encodeURIComponent(query);
}

// Return the direct album search endpoint
function getSearchAlbumsUrl(query) {
    return PROXY_URL + "/api/v1/search?provider=saavn&query=" + encodeURIComponent(query);
}

// Return autocomplete search endpoint
function getSearchAllUrl(query) {
    return PROXY_URL + "/api/v1/search?query=" + encodeURIComponent(query);
}

// Return artist details endpoint
function getArtistDetailsUrl(id) {
    var cleanId = id ? id.replace('saavn:', '') : '';
    return PROXY_URL + "/api/v1/saavn/artist?id=" + encodeURIComponent(cleanId);
}

// Return playlist tracks endpoint (resolves all songs via Cloudflare Edge)
function getPlaylistTracksUrl(id) {
    var cleanId = id ? id.replace('saavn:', '') : '';
    var isNumeric = /^\d+$/.test(cleanId);
    var saavnUrl = isNumeric
        ? "https://www.jiosaavn.com/api.php?__call=playlist.getDetails&_format=json&cc=in&_marker=0&api_version=4&ctx=web6dot0&listid=" + encodeURIComponent(cleanId)
        : "https://www.jiosaavn.com/api.php?__call=webapi.get&token=" + encodeURIComponent(cleanId) + "&type=playlist&_format=json&_marker=0&api_version=4&ctx=web6dot0";
    return PROXY_URL + "/api/v1/image-proxy?url=" + encodeURIComponent(saavnUrl);
}

// Return album tracks endpoint (resolves all songs via Cloudflare Edge)
function getAlbumTracksUrl(id) {
    var cleanId = id ? id.replace('saavn:', '') : '';
    return PROXY_URL + "/api/v1/saavn/album?id=" + encodeURIComponent(cleanId);
}

// Return charts endpoint
function getChartsUrl() {
    return PROXY_URL + "/api/v1/charts/trending";
}

// Return podcasts search endpoint
function getSearchPodcastsUrl(query) {
    return BACKEND_URL + "/api/v1/search/podcasts?query=" + encodeURIComponent(query);
}

// Return the direct audio/video stream API endpoint
function getStreamUrl(id, query, encryptedUrl) {
    var cleanId = id ? id.replace('saavn:', '').replace('youtube:', '') : '';
    if (query) {
        return BACKEND_URL + "/api/v1/video/stream?id=" + encodeURIComponent(cleanId) + "&query=" + encodeURIComponent(query);
    }
    if (encryptedUrl) {
        return PROXY_URL + "/api/v1/stream?encryptedUrl=" + encodeURIComponent(encryptedUrl);
    }
    return PROXY_URL + "/api/v1/stream?id=" + encodeURIComponent(cleanId);
}

// Return home launch feed endpoint
function getHomeFeedUrl() {
    return PROXY_URL + "/api/v1/saavn/home";
}

function getTrendingVideosUrl() {
    return BACKEND_URL + "/api/v1/videos/trending";
}

function getLyricsUrl(track, artist) {
    return PROXY_URL + "/api/v1/lyrics?track=" + encodeURIComponent(track) + "&artist=" + encodeURIComponent(artist);
}
