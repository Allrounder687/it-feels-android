const BACKEND_URL = "https://it-feels-backend.cleverfox687.workers.dev"; // Live Cloudflare Worker URL

// Return the direct search API endpoint
function getSearchUrl(query) {
    return BACKEND_URL + "/api/v1/search?query=" + encodeURIComponent(query);
}

function getSearchPlaylistsUrl(query) {
    return "https://www.jiosaavn.com/api.php?__call=search.getPlaylistResults&_format=json&_marker=0&api_version=4&p=1&n=20&q=" + encodeURIComponent(query);
}

function getSearchAlbumsUrl(query) {
    return "https://www.jiosaavn.com/api.php?__call=search.getAlbumResults&_format=json&_marker=0&api_version=4&p=1&n=20&q=" + encodeURIComponent(query);
}

function getSearchAllUrl(query) {
    return "https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0&api_version=4&ctx=web6dot0&query=" + encodeURIComponent(query);
}

function getArtistDetailsUrl(id) {
    return "https://www.jiosaavn.com/api.php?__call=artist.getArtistPageDetails&_format=json&_marker=0&api_version=4&artistId=" + encodeURIComponent(id);
}

function getPlaylistTracksUrl(id) {
    return "https://www.jiosaavn.com/api.php?__call=playlist.getDetails&_format=json&cc=in&_marker=0&api_version=4&ctx=web6dot0&listid=" + encodeURIComponent(id);
}

function getAlbumTracksUrl(id) {
    return "https://www.jiosaavn.com/api.php?__call=content.getAlbumDetails&_format=json&_marker=0&api_version=4&albumid=" + encodeURIComponent(id);
}

function getChartsUrl() {
    return "https://api.deezer.com/chart";
}

function getSearchPodcastsUrl(query) {
    return BACKEND_URL + "/api/v1/search/podcasts?query=" + encodeURIComponent(query);
}

// Return the direct stream API endpoint
function getStreamUrl(id, query) {
    if (query) {
        return BACKEND_URL + "/api/v1/video/stream?id=" + encodeURIComponent(id) + "&query=" + encodeURIComponent(query);
    }
    return BACKEND_URL + "/api/v1/video/stream?id=" + encodeURIComponent("search:" + id);
}

function getHomeFeedUrl() {
    return BACKEND_URL + "/api/v1/home";
}

function getTrendingVideosUrl() {
    return BACKEND_URL + "/api/v1/videos/trending";
}

function getLyricsUrl(track, artist) {
    return BACKEND_URL + "/api/v1/lyrics?track=" + encodeURIComponent(track) + "&artist=" + encodeURIComponent(artist);
}
