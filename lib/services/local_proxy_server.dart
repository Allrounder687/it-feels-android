import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class LocalProxyServer {
  static HttpServer? _server;
  static int _port = 0;
  static bool get isRunning => _server != null;

  static HttpClient? _client;

  static HttpClient get _httpClient {
    return _client ??= HttpClient()
      ..autoUncompress = false
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 15);
  }

  static Future<void> start() async {
    if (_server != null || kIsWeb || !Platform.isWindows) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      debugPrint('[LocalProxyServer] Started on port $_port');

      _server!.listen((HttpRequest request) async {
        try {
          final targetUrl = request.uri.queryParameters['url'];
          if (targetUrl == null) {
            request.response.statusCode = 400;
            await request.response.close();
            return;
          }

          HttpClientRequest? clientRequest;
          try {
            clientRequest = await _httpClient.getUrl(Uri.parse(targetUrl));
          } on HandshakeException catch (e) {
            debugPrint('[LocalProxyServer] Upstream TLS handshake failed for $targetUrl: $e');
            request.response.statusCode = 502;
            await request.response.close();
            return;
          } on SocketException catch (e) {
            debugPrint('[LocalProxyServer] Upstream socket connection error: $e');
            request.response.statusCode = 502;
            await request.response.close();
            return;
          } catch (e) {
            debugPrint('[LocalProxyServer] Upstream request dispatch failed: $e');
            request.response.statusCode = 502;
            await request.response.close();
            return;
          }

          clientRequest.headers.set(
            'User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36',
          );
          if (targetUrl.contains('youtube') || targetUrl.contains('googlevideo')) {
            clientRequest.headers.set('Referer', 'https://www.youtube.com/');
          } else if (targetUrl.contains('saavn')) {
            clientRequest.headers.set('Referer', 'https://www.jiosaavn.com/');
          }

          if (request.headers.value('range') != null) {
            clientRequest.headers.set('range', request.headers.value('range')!);
          }

          HttpClientResponse? clientResponse;
          try {
            clientResponse = await clientRequest.close();
          } on HandshakeException catch (e) {
            debugPrint('[LocalProxyServer] Upstream handshake aborted during close: $e');
            request.response.statusCode = 502;
            await request.response.close();
            return;
          } catch (e) {
            debugPrint('[LocalProxyServer] Failed to receive upstream headers: $e');
            request.response.statusCode = 502;
            await request.response.close();
            return;
          }

          request.response.statusCode = clientResponse.statusCode;
          clientResponse.headers.forEach((name, values) {
            for (final value in values) {
              request.response.headers.add(name, value);
            }
          });

          try {
            await clientResponse.pipe(request.response);
          } on SocketException catch (_) {
            // Downstream audio player disconnected or seeked. Normal during media streaming.
          } on HttpException catch (_) {
            // Connection closed prematurely by client or server.
          } on HandshakeException catch (e) {
            debugPrint('[LocalProxyServer] Upstream TLS handshake interrupted during streaming: $e');
          } catch (e) {
            debugPrint('[LocalProxyServer] Stream pipe error: $e');
          }
        } catch (e) {
          debugPrint('[LocalProxyServer] Request error: $e');
          try {
            request.response.statusCode = 500;
            await request.response.close();
          } catch (_) {}
        }
      });
    } catch (e) {
      debugPrint('[LocalProxyServer] Failed to bind server: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _server?.close(force: true);
      _server = null;
      _port = 0;
      _client?.close(force: true);
      _client = null;
      debugPrint('[LocalProxyServer] Stopped');
    } catch (e) {
      debugPrint('[LocalProxyServer] Stop error: $e');
    }
  }

  static String getProxyUrl(String originalUrl) {
    if (!isRunning || kIsWeb || !Platform.isWindows) return originalUrl;
    return 'http://127.0.0.1:$_port/?url=${Uri.encodeComponent(originalUrl)}';
  }
}
