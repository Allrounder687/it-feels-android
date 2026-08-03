import 'dart:io';
import 'package:flutter/foundation.dart';

class LocalProxyServer {
  static HttpServer? _server;
  static int _port = 0;
  static bool get isRunning => _server != null;

  static Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    debugPrint('[LocalProxyServer] Started on port $_port');

    _server!.listen((HttpRequest request) async {
      try {
        final targetUrl = request.uri.queryParameters['url'];
        if (targetUrl == null) {
          request.response.statusCode = 400;
          request.response.close();
          return;
        }

        final client = HttpClient();
        final clientRequest = await client.getUrl(Uri.parse(targetUrl));
        clientRequest.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36');
        clientRequest.headers.set('Referer', 'https://www.youtube.com/');
        
        if (request.headers.value('range') != null) {
          clientRequest.headers.set('range', request.headers.value('range')!);
        }

        final clientResponse = await clientRequest.close();
        
        request.response.statusCode = clientResponse.statusCode;
        clientResponse.headers.forEach((name, values) {
          for (final value in values) {
            request.response.headers.add(name, value);
          }
        });

        await clientResponse.pipe(request.response);
      } catch (e) {
        debugPrint('[LocalProxyServer] Error: $e');
        try {
          request.response.statusCode = 500;
          request.response.close();
        } catch (_) {}
      }
    });
  }

  static String getProxyUrl(String originalUrl) {
    if (!isRunning || kIsWeb) return originalUrl;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'http://127.0.0.1:$_port/?url=${Uri.encodeComponent(originalUrl)}';
    }
    return originalUrl;
  }
}
