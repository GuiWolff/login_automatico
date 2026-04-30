import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:oauth2_client/interfaces.dart';
import 'package:web/web.dart' as web;

BaseWebAuth createPlatformOAuth2WebAuth() => _CompatBrowserOAuth2WebAuth();

class _CompatBrowserOAuth2WebAuth implements BaseWebAuth {
  static const String _legacyMessageKey = 'flutter-web-auth-2';

  @override
  Future<String> authenticate({
    required String callbackUrlScheme,
    required String url,
    required String redirectUrl,
    Map<String, dynamic>? opts,
  }) async {
    final popup = web.window.open(
      url,
      'oauth2_client::authenticateWindow',
      'menubar=no,status=no,scrollbars=no,width=1000,height=500',
    );

    final String redirectOrigin = Uri.parse(redirectUrl).origin;
    final web.MessageEvent messageEvent = await web.window.onMessage.firstWhere(
      (web.MessageEvent event) => event.origin == redirectOrigin,
    );

    popup?.close();

    final String? callbackUrl = _callbackUrlFromMessage(messageEvent.data);
    if (callbackUrl == null || callbackUrl.isEmpty) {
      throw StateError('Callback OAuth nao retornou a URL de autenticacao.');
    }

    return callbackUrl;
  }

  String? _callbackUrlFromMessage(JSAny? data) {
    if (data == null) {
      return null;
    }

    if (data.typeofEquals('string')) {
      return (data as JSString).toDart;
    }

    final JSAny? legacyUrl = (data as JSObject).getProperty(
      _legacyMessageKey.toJS,
    );
    if (legacyUrl != null && legacyUrl.typeofEquals('string')) {
      return (legacyUrl as JSString).toDart;
    }

    return data.toString();
  }
}
