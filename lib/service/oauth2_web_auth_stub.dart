import 'package:oauth2_client/interfaces.dart';

BaseWebAuth createPlatformOAuth2WebAuth() => _UnsupportedOAuth2WebAuth();

class _UnsupportedOAuth2WebAuth implements BaseWebAuth {
  @override
  Future<String> authenticate({
    required String callbackUrlScheme,
    required String url,
    required String redirectUrl,
    Map<String, dynamic>? opts,
  }) {
    throw UnsupportedError('OAuth2 Web Auth so esta disponivel no Web.');
  }
}
