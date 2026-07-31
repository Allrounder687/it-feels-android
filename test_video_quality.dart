import 'dart:convert';
import 'package:http/http.dart' as http;

/// Diagnostic tool for IT Feels high-quality video stream verification
/// Run: dart test_video_quality.dart
Future<void> main() async {
  final cloudflareWorkerUrl = 'https://it-feels-proxy.cleverfox687.workers.dev';
  final renderProxyUrl = 'https://it-feels-android.onrender.com'; // Update this to your actual Render URL
  final testVideoId = 'dQw4w9WgXcQ'; // Rick Astley - well-known video for testing

  print('═══ IT Feels Video Quality Diagnostic ═══');
  print('Target video: $testVideoId\n');

  // Test 1: Cloudflare Worker video route
  print('1️⃣  Testing Cloudflare Worker /api/v1/video');
  try {
    final uri = Uri.parse('$cloudflareWorkerUrl/api/v1/video').replace(
      queryParameters: {'id': 'youtube:$testVideoId'},
    );
    final res = await http.get(uri, headers: {'X-Feels-Secret': 'development_secret_123'}).timeout(const Duration(seconds: 20));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final streams = data['streams'] ?? [];
      final qualities = streams.map((s) => s['quality'] ?? 'unknown').toSet().toList();
      print('   ✅ Status: 200');
      print('   📺 Title: ${data['title'] ?? 'N/A'}');
      print('   📊 Available qualities: $qualities');
      print('   🔢 Stream count: ${streams.length}');
      if (qualities.isEmpty) {
        print('   ⚠️  WARNING: No streams returned!');
      }
    } else {
      print('   ❌ Status: ${res.statusCode}');
      print('   Body: ${res.body}');
    }
  } catch (e) {
    print('   ❌ Error: $e');
  }

  print('\n2️⃣  Testing Render yt-dlp Proxy /api/streams');
  try {
    final uri = Uri.parse('$renderProxyUrl/api/streams').replace(
      queryParameters: {'videoId': testVideoId},
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final streams = data['streams'] ?? [];
      final qualities = streams.map((s) => s['quality'] ?? 'unknown').toSet().toList();
      print('   ✅ Status: 200');
      print('   📺 Title: ${data['title'] ?? 'N/A'}');
      print('   📊 Available qualities: $qualities');
      print('   🔢 Stream count: ${streams.length}');
      if (data['audioUrl']?.isNotEmpty ?? false) {
        print('   🎵 Audio stream: Present');
      }
    } else {
      print('   ❌ Status: ${res.statusCode}');
      print('   Body: ${res.body}');
    }
  } catch (e) {
    print('   ❌ Error: $e (Is the Render service deployed and running?)');
  }

  print('\n3️⃣  Testing Piped API instances directly');
  final pipedInstances = [
    'https://pipedapi.adminforge.de',
    'https://pipedapi.tokhmi.xyz',
    'https://pipedapi.palmo.fr',
    'https://pipedapi.drgns.space',
  ];
  int workingPiped = 0;
  for (final instance in pipedInstances) {
    try {
      final uri = Uri.parse('$instance/streams/$testVideoId');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final videoStreams = data['videoStreams'] ?? [];
        final audioStreams = data['audioStreams'] ?? [];
        print('   ✅ $instance: ${videoStreams.length} video, ${audioStreams.length} audio');
        workingPiped++;
      } else {
        print('   ❌ $instance: HTTP ${res.statusCode}');
      }
    } catch (e) {
      print('   ❌ $instance: $e');
    }
  }
  print('   📊 Working Piped instances: $workingPiped/${pipedInstances.length}');

  print('\n═══ Summary ═══');
  print('If Cloudflare Worker returns no streams, add Render Proxy as fallback in Worker route.');
  print('If Render returns no streams, check service logs for yt-dlp extraction failures.');
  print('If only some Piped instances work, the failover in backend_api_service.dart should handle it.');
}
