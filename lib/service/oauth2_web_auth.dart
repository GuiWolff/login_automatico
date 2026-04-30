import 'package:oauth2_client/interfaces.dart';

import 'oauth2_web_auth_stub.dart'
    if (dart.library.js_interop) 'oauth2_web_auth_browser.dart';

BaseWebAuth createOAuth2WebAuth() => createPlatformOAuth2WebAuth();
