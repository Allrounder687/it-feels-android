import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'dart:isolate';

Future<String?> _fetchCanvasUrl(String query) async {
  final yt = YoutubeExplode();
  try {
    print('Searching for: \$query');
    final searchList = await yt.search.search(query);
    if (searchList.isEmpty) {
      print('Search list empty');
      yt.close();
      return null;
    }

    Video? targetVideo;
    for (final video in searchList) {
      if (video.duration != null && video.duration!.inMinutes <= 2) {
        targetVideo = video;
        break;
      }
    }

    if (targetVideo == null) {
      print('No target video found under 2 minutes');
      yt.close();
      return null;
    }

    print('Found video: \${targetVideo.title}');
    final manifest = await yt.videos.streamsClient.getManifest(targetVideo.id);
    final streamInfo = manifest.muxed.withHighestBitrate();
    yt.close();
    return streamInfo.url.toString();
  } catch (e, stack) {
    print('Error: \$e');
    print(stack);
    yt.close();
    return null;
  }
}

void main() async {
  final url = await _fetchCanvasUrl("shape of you ed sheeran #shorts");
  print("Result: \$url");
}
