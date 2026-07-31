import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  final manifest = await yt.videos.streamsClient.getManifest('2Vv-BfVoq4g');
  final stream = manifest.muxed.withHighestBitrate();
  print('Stream URL: ${stream.url}');
  
  final res = await http.get(stream.url, headers: {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36',
    'Referer': 'https://www.youtube.com/',
  });
  
  print('HTTP Status (With headers): ${res.statusCode}');

  final res2 = await http.get(stream.url);
  print('HTTP Status (No headers): ${res2.statusCode}');
  
  yt.close();
  print('Done');
}
