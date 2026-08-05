enum ShelfType { songCarousel, playlistCarousel, artistGrid }

class FeedShelf {
  final String title;
  final ShelfType type;
  final List<dynamic> items; // Song, Playlist, or String (artist name)

  FeedShelf({
    required this.title,
    required this.type,
    required this.items,
  });
}
