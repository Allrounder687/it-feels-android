# JioSaavn API Usage

This document details the interaction with the JioSaavn API within the PixelPlayer Flutter application. The `JioSaavnApiService` (found in `lib/data/services/jiosaavn_api_service.dart`) acts as the primary interface for fetching music-related data.

---

## 1. Core API Details

*   **Base URL:** `https://www.jiosaavn.com/api.php`
*   **Request Headers:**
    *   `User-Agent`: Mimics a web browser to ensure compatibility (`Mozilla/5.0...`).
    *   `Accept`: `application/json`.
*   **Common Query Parameters:**
    *   `__call`: Specifies the API method to invoke (e.g., `autocomplete.get`, `content.getHomepageData`).
    *   `_format`: `json` (always requested in JSON format).
    *   `_marker`: `0`.
    *   `api_version`: `4`.
    *   `ctx`: `web6dot0`.
    *   `cc`: `in` (for country code, used in some detail requests).

---

## 2. API Endpoints and Usage

### A. Search All Categories

*   **Method:** `searchAll(String query)`
*   **JioSaavn Endpoint:** `__call=autocomplete.get`
*   **Purpose:** Provides a comprehensive search across songs, albums, and playlists based on a user's query.
*   **Request Parameters:**
    *   `query`: The user's search term (URL-encoded).
*   **Response Structure (Simplified):**
    ```json
    {
      "songs": { "data": [{ /* Song JSON */ }] },
      "albums": { "data": [{ /* Playlist/Album JSON */ }] },
      "playlists": { "data": [{ /* Playlist JSON */ }] }
    }
    ```
    *   The `data` arrays contain JSON objects which are mapped to `Song` and `Playlist` models.
*   **Error Handling:** Returns empty lists for `songs`, `albums`, and `playlists` on HTTP status codes other than 200 or on any exception during the API call or JSON parsing. Errors are printed to debug console using `debugPrint`.

### B. Search Songs (Convenience Method)

*   **Method:** `searchSongs(String query)`
*   **Purpose:** A wrapper around `searchAll` to specifically return only the list of `Song` objects.

### C. Fetch Homepage Data

*   **Method:** `fetchHomepageData()`
*   **JioSaavn Endpoint:** `__call=content.getHomepageData`
*   **Purpose:** Retrieves various trending and curated content for the application's home screen, such as top charts, featured playlists, and new albums.
*   **Request Parameters:** None specific beyond common ones.
*   **Response Structure (Simplified):**
    ```json
    {
      "charts": [{ "id": "...", "listid": "...", /* Chart details */ }],
      "top_playlists": [{ /* Playlist JSON */ }],
      "featured_playlists": [{ /* Playlist JSON */ }],
      "new_albums": [{ /* Album JSON */ }]
    }
    ```
    *   The method processes these sections, sometimes making a subsequent `fetchPlaylistDetails` call for the first chart to get trending songs.
*   **Error Handling:** Returns empty lists for `trending` songs and `playlists` on failure. Errors are printed to debug console.

### D. Fetch Playlist Details

*   **Method:** `fetchPlaylistDetails(String listId)`
*   **JioSaavn Endpoint:** `__call=playlist.getDetails`
*   **Purpose:** Fetches detailed information, including the list of songs, for a given playlist ID.
*   **Request Parameters:**
    *   `listid`: The ID of the playlist.
*   **Response Structure (Simplified):**
    ```json
    {
      "listname": "...",
      "songs": [{ /* Song JSON */ }],
      "image": "..."
    }
    ```
    *   Handles various key names (`listname`, `title`, `name`, `songs`, `list`) for flexibility.
*   **Error Handling:** Returns an empty map with `name` and `songs` on failure. Errors are printed to debug console.

### E. Fetch Album Details

*   **Method:** `fetchAlbumDetails(String albumId)`
*   **JioSaavn Endpoint:** `__call=content.getAlbumDetails`
*   **Purpose:** Fetches detailed information, including the list of songs, for a given album ID.
*   **Request Parameters:**
    *   `albumid`: The ID of the album.
*   **Response Structure (Simplified):**
    ```json
    {
      "title": "...",
      "songs": [{ /* Song JSON */ }],
      "image": "..."
    }
    ```
    *   Handles various key names (`title`, `name`, `songs`, `list`).
*   **Error Handling:** Returns an empty map with `name` and `songs` on failure. Errors are printed to debug console.

### F. Get Stream URL (Decryption & Resolution)

*   **Method:** `getStreamUrl(Song song)`
*   **JioSaavn Endpoint:** `__call=song.getDetails` (only if `encryptedMediaUrl` is missing from the initial `Song` object)
*   **Purpose:** Resolves the playable 320kbps audio URL for a given `Song`. This involves decryption if an `encryptedMediaUrl` is present.
*   **Request Parameters:**
    *   `pids`: The `saavnId` of the song (if `encryptedMediaUrl` needs to be fetched).
*   **Logic Flow:**
    1.  **Cache Check:** First checks an in-memory `_streamCache` to avoid redundant API calls and decryption.
    2.  **Encrypted URL Check:** If `song.encryptedMediaUrl` is not already available, it makes an API call to `song.getDetails` to fetch it.
    3.  **Decryption:** Once an encrypted URL (`encUrl`) is obtained, it uses `DesDecryptor.decrypt(encUrl)` to get the decrypted string.
    4.  **URL Resolution:** Calls `DesDecryptor.get320kbpsUrl(decrypted)` to extract the high-quality stream URL.
    5.  **Caching:** Caches the final stream URL for the song's `saavnId`.
*   **Error Handling:** Returns `null` if no encrypted URL is found, decryption fails, or any exception occurs. Errors are printed to debug console.

---

## 3. Error Handling Strategy

The `JioSaavnApiService` generally employs a defensive error handling strategy:
*   HTTP requests are wrapped in `try-catch` blocks to handle network issues or other exceptions.
*   If an HTTP request fails (non-200 status code) or an exception occurs, methods typically return empty lists, empty maps, or `null` values as appropriate, preventing crashes.
*   Errors are logged to the debug console using `debugPrint` with a `[JioSaavnApiService]` prefix.

---

## 4. Considerations & Limitations

*   **JioSaavn API Stability:** The JioSaavn API used here is unofficial and may change without notice, potentially breaking functionality.
*   **Rate Limiting:** There are no explicit rate-limiting mechanisms implemented client-side. Excessive requests might lead to temporary IP blocking by JioSaavn.
*   **Authentication:** This service does not handle user authentication for JioSaavn. It relies on publicly accessible endpoints.
*   **Data Consistency:** The API responses can sometimes be inconsistent in key naming (`id` vs `listid`, `title` vs `name`), which the `fromJson` methods in `Song` and `Playlist` attempt to normalize.
