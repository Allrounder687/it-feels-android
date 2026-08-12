import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  try {
    final videoId = '2Vv-BfVoq4g';
    final targetVideo = await yt.videos.get(VideoId(videoId));
    print('Got target video');
    final related = await yt.videos.getRelatedVideos(targetVideo);
    print('Got related videos list of length ${related?.length}');
    if (related != null) {
      for (final video in related) {
        try {
          print('Video: ${video.title}');
          print('Views: ${video.engagement.viewCount}');
        } catch (e) {
          print('Error for video ${video.title}: $e');
        }
      }
    }
  } catch (e, stack) {
    print('Error: $e');
    print(stack);
  } finally {
    yt.close();
  }
}
