import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  final manifest = await yt.videos.streamsClient.getManifest('2Vv-BfVoq4g');
  final stream = manifest.videoOnly.withHighestBitrate();
  print('Stream URL: ${stream.url}');
  
  // Test Range request
  final res = await http.get(stream.url, headers: {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36',
    'Referer': 'https://www.youtube.com/',
    'Range': 'bytes=0-1000',
  });
  
  print('HTTP Status (With Range + Mobile): ${res.statusCode}');

  final res2 = await http.get(stream.url, headers: {
    'Range': 'bytes=0-1000',
  });
  
  print('HTTP Status (With Range + No Agent): ${res2.statusCode}');
  
  yt.close();
}
