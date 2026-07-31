import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

class SpotifyScraperService {
  /// Extracts the track list from a public Spotify playlist URL.
  /// Returns a list of maps containing 'title' and 'artist'.
  static Future<List<Map<String, String>>> extractTracksFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      });

      if (response.statusCode == 200) {
        final document = parse(response.body);
        final List<Map<String, String>> tracks = [];
        
        // Spotify SSR HTML structure often contains tracks in meta tags or script tags.
        // This is a basic implementation of scraping for the MVP.
        // In a production environment, this would hit a RapidAPI or Spotify Client Credentials endpoint.
        
        // We'll try to extract from the raw HTML if they are listed in list items
        final trackElements = document.querySelectorAll('div[data-testid="tracklist-row"]');
        
        for (var element in trackElements) {
          final titleElement = element.querySelector('div[dir="auto"]');
          final artistElements = element.querySelectorAll('a[href^="/artist/"]');
          
          if (titleElement != null && artistElements.isNotEmpty) {
            final title = titleElement.text.trim();
            final artist = artistElements.map((e) => e.text.trim()).join(', ');
            tracks.add({'title': title, 'artist': artist});
          }
        }
        
        return tracks;
      }
    } catch (e) {
      print('Error scraping Spotify: $e');
    }
    return [];
  }
}
