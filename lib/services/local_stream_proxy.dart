import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LocalStreamProxy {
  static HttpServer? _server;
  static String? _currentStreamUrl;
  static int? _port;

  /// Starts the proxy server if not already running, sets the current target URL,
  /// and returns the local proxy URL for ExoPlayer to consume.
  static Future<String> getProxyUrl(String streamUrl) async {
    _currentStreamUrl = streamUrl;
    
    if (_server != null) {
      return 'http://127.0.0.1:$_port/';
    }
    
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      
      _server!.listen((HttpRequest request) async {
        try {
          if (_currentStreamUrl == null) {
            request.response.statusCode = 404;
            request.response.close();
            return;
          }

          final clientReq = http.Request('GET', Uri.parse(_currentStreamUrl!));
          
          // Forward the essential Range header from ExoPlayer
          final rangeHeader = request.headers.value('range');
          if (rangeHeader != null) {
            clientReq.headers['range'] = rangeHeader;
          }
          
          // Add spoofed mobile headers to satisfy YouTube's anti-bot system
          clientReq.headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36';
          
          final client = http.Client();
          final streamedRes = await client.send(clientReq);
          
          request.response.statusCode = streamedRes.statusCode;
          
          // Forward response headers back to ExoPlayer
          streamedRes.headers.forEach((key, value) {
            // Avoid setting restricted HTTP/2 headers on dart HttpServer
            if (key.toLowerCase() != 'transfer-encoding' && key.toLowerCase() != 'content-encoding') {
              try {
                request.response.headers.set(key, value);
              } catch (_) {}
            }
          });
          
          await streamedRes.stream.pipe(request.response);
        } catch (e) {
          debugPrint('[LocalStreamProxy] Error serving request: $e');
          try {
            request.response.statusCode = 500;
            request.response.close();
          } catch (_) {}
        }
      });
      
      debugPrint('[LocalStreamProxy] Started on port $_port');
    } catch (e) {
      debugPrint('[LocalStreamProxy] Failed to start server: $e');
      // Fallback to original URL if server fails
      return streamUrl;
    }
    
    return 'http://127.0.0.1:$_port/';
  }
}
