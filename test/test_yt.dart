import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  try {
    // See if trending is exposed
    // Let's just search for popular videos
    final results = await yt.search.search('trending music videos');
    print('Found ${results.length} videos');
    for (final video in results.take(3)) {
      print('${video.title} by ${video.author}');
    }
  } finally {
    yt.close();
  }
}
