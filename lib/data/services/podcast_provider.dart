import 'package:it_feels_music/data/models/song_model.dart';

abstract class PodcastProvider {
  /// Fetches a list of podcast episodes based on a query.
  Future<List<Song>> searchPodcasts(String query, {int count = 20});
}
