import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:it_feels_music/features/connected_music/account_browser_gateway.dart';
import 'package:it_feels_music/features/connected_music/connected_music_models.dart';

/// Native plumbing only. Does not access, sign in to, or modify a real account.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('secure session storage and native account browser round-trip', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Checking connected music browser')),
        ),
      ),
    );
    final gateway = AccountBrowserGateway();
    final addon = accountAddons.first;
    await gateway.install(addon);
    final environment = await gateway.environment(addon);
    const key = 'it_feels.connected_music.native_test';
    const value = 'synthetic-test-value';
    final manager = CookieManager.instance(webViewEnvironment: environment);
    final origin = WebUri('https://it-feels-native-test.invalid');
    final ready = Completer<void>();
    final browser = HeadlessInAppWebView(
      webViewEnvironment: environment,
      initialData: InAppWebViewInitialData(
        data:
            '<!doctype html><html><body><p id="ready">Native browser ready</p></body></html>',
      ),
      onLoadStop: (_, _) {
        if (!ready.isCompleted) ready.complete();
      },
    );
    try {
      await gateway.secrets.write(key: key, value: value);
      expect(await gateway.secrets.read(key: key), value);
      await manager.setCookie(
        url: origin,
        name: 'it_feels_test',
        value: value,
        isSecure: true,
      );
      expect(
        (await manager.getCookie(url: origin, name: 'it_feels_test'))?.value,
        value,
      );
      await browser.run();
      await ready.future.timeout(const Duration(seconds: 30));
      expect(
        await browser.webViewController!.evaluateJavascript(
          source: 'document.getElementById("ready").textContent',
        ),
        'Native browser ready',
      );
    } finally {
      await browser.dispose();
      await manager.deleteCookie(url: origin, name: 'it_feels_test');
      await gateway.secrets.delete(key: key);
      gateway.dispose();
    }
  });
}
