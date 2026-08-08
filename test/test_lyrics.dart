import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final title = 'Tabassum';
  final artist = 'A.R. Rahman';
  final duration = 320; // from the screenshot 05:20 = 320s

  print('--- LRCLIB /api/get ---');
  final lrclibGetUrl = Uri.parse('https://lrclib.net/api/get?track_name=${Uri.encodeComponent(title)}&artist_name=${Uri.encodeComponent(artist)}&duration=$duration');
  final res1 = await http.get(lrclibGetUrl);
  print('Status: ${res1.statusCode}, Body: ${res1.body}');

  print('\n--- LRCLIB /api/search ---');
  final lrclibSearchUrl = Uri.parse('https://lrclib.net/api/search?q=${Uri.encodeComponent("$artist $title")}');
  final res2 = await http.get(lrclibSearchUrl);
  print('Status: ${res2.statusCode}, Body: ${res2.body.substring(0, res2.body.length > 300 ? 300 : res2.body.length)}');

  print('\n--- Musixmatch Token ---');
  final tokenUrl = Uri.parse('https://apic-desktop.musixmatch.com/ws/1.1/token.get?app_id=web-desktop-app-v1.0');
  final tokenRes = await http.get(tokenUrl, headers: {'User-Agent': 'Mozilla/5.0'});
  final tokenData = jsonDecode(tokenRes.body);
  final mxmToken = tokenData['message']['body']['user_token'];
  print('Token: $mxmToken');

  print('\n--- Musixmatch Search ---');
  final searchUrl = Uri.parse('https://apic-desktop.musixmatch.com/ws/1.1/macro.subtitles.get?format=json&q_track=${Uri.encodeComponent(title)}&q_artist=${Uri.encodeComponent(artist)}&user_language=en&namespace=lyrics_synched&f_subtitle_length_max_deviation=1&subtitle_format=lrc&app_id=web-desktop-app-v1.0&usertoken=$mxmToken');
  final searchRes = await http.get(searchUrl, headers: {'User-Agent': 'Mozilla/5.0', 'Cookie': 'x-mxm-token-guid=$mxmToken'});
  print('Status: ${searchRes.statusCode}, Body: ${searchRes.body.substring(0, searchRes.body.length > 300 ? 300 : searchRes.body.length)}');
}
