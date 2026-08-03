import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  final manifest = await yt.videos.streamsClient.getManifest('xEBVyHzyIM4');
  
  print('Muxed Streams:');
  for (final stream in manifest.muxed) {
    print('- ${stream.container.name} | ${stream.videoQuality.name} | URL Length: ${stream.url.toString().length}');
  }
  
  yt.close();
}
