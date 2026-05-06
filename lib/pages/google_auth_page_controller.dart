import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:login_automatico/service/oauth2_web_auth.dart';
import 'package:oauth2_client/access_token_response.dart';
import 'package:oauth2_client/oauth2_client.dart';
import 'package:openid_client/openid_client.dart' as oidc;

class GoogleAuthPageController extends ChangeNotifier {

  static const String _issuerUrl = 'https://open-id.ggwpcode.com.br/realms/login-automatico';

  static const String _authorizationEndpointUrl = '$_issuerUrl/protocol/openid-connect/auth';

  static const String _tokenEndpointUrl = '$_issuerUrl/protocol/openid-connect/token';

  static const String _logoutEndpointUrl = '$_issuerUrl/protocol/openid-connect/logout';

  static const String _clientId = 'login_automatico';

  static const String _windowsRedirectUrl = 'http://127.0.0.1:54322/callback';

  static const String _webRedirectUrl = 'https://srv.ggwpcode.com.br/callback';

  static const List<String> _scopes = <String>[
    'openid',
    'profile',
    'email',
    'offline_access',
  ];

  bool _isDisposed = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _authJson;
  oidc.Credential? _credential;
  AccessTokenResponse? _webTokenResponse;
  String? _refreshTokenValue;
  String? _idTokenValue;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get authJson => _authJson;
  bool get hasAuthData => _authJson != null;
  bool get hasRefreshToken => _refreshTokenValue != null;
  bool get canLogin => !_isLoading && isSupportedPlatform;

  bool get isSupportedPlatform =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.windows;

  String get unsupportedPlatformMessage =>
      'Esta tela esta configurada para autenticar via Keycloak em Flutter Web '
      'ou Flutter Windows.';

  Future<void> loginWithProvider(String provider) {
    debugPrint('Iniciando login Keycloak com kc_idp_hint=$provider');
    return _signIn(idpHint: provider);
  }

  Future<void> loginWithEmail() {
    debugPrint('Iniciando login Keycloak sem kc_idp_hint.');
    return _signIn();
  }

  Future<void> refreshToken() async {
    if (kIsWeb) {
      await _refreshWebToken();
      return;
    }

    final oidc.Credential? credential = _credential;
    if (credential == null || _refreshTokenValue == null) {
      return;
    }

    _startLoading();

    try {
      final oidc.TokenResponse tokenResponse = await credential
          .getTokenResponse(true);
      _setTokenData(tokenResponse);
    } catch (error) {
      _setError(error);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    if (!isSupportedPlatform) {
      _clearLocalSession();
      return;
    }

    final String? idToken = _idTokenValue;
    final Uri postLogoutRedirectUri = _postLogoutRedirectUri();

    _startLoading();

    try {
      final Uri logoutUri = Uri.parse(_logoutEndpointUrl).replace(
        queryParameters: <String, String>{
          if (idToken != null && idToken.isNotEmpty) 'id_token_hint': idToken,
          'post_logout_redirect_uri': postLogoutRedirectUri.toString(),
        },
      );

      await FlutterWebAuth2.authenticate(
        url: logoutUri.toString(),
        callbackUrlScheme: kIsWeb
            ? postLogoutRedirectUri.scheme
            : postLogoutRedirectUri.toString(),
        options: FlutterWebAuth2Options(
          useWebview: false,
          windowName: '_blank',
          debugOrigin: kIsWeb ? postLogoutRedirectUri.origin : null,
        ),
      );
    } catch (error) {
      debugPrint('Falha ao efetuar logout no Keycloak: $error');
    } finally {
      _clearLocalSession();
    }
  }

  Future<void> _signIn({String? idpHint}) async {
    if (!isSupportedPlatform) {
      _setError(unsupportedPlatformMessage);
      return;
    }

    _startLoading();

    try {
      if (kIsWeb) {
        await _startWebAuthentication(idpHint: idpHint);
        return;
      }

      final oidc.Credential credential = await _authenticateWindows(
        idpHint: idpHint,
      );
      final oidc.TokenResponse tokenResponse = await credential
          .getTokenResponse();

      _credential = credential;
      _webTokenResponse = null;
      _setTokenData(tokenResponse);
    } catch (error) {
      _setError(error);
    } finally {
      _setLoading(false);
    }
  }

  Future<oidc.Credential> _authenticateWindows({String? idpHint}) async {
    final oidc.Issuer issuer = await oidc.Issuer.discover(
      Uri.parse(_issuerUrl),
    );
    final oidc.Client client = oidc.Client(issuer, _clientId);
    final Uri redirectUri = _redirectUri();

    final oidc.Flow flow = oidc.Flow.authorizationCodeWithPKCE(
      client,
      scopes: _scopes,
      prompt: 'login',
      additionalParameters: _idpHintParameters(idpHint),
    )..redirectUri = redirectUri;

    final String callbackUrl = await FlutterWebAuth2.authenticate(
      url: flow.authenticationUri.toString(),
      callbackUrlScheme: kIsWeb ? redirectUri.scheme : redirectUri.toString(),
      options: FlutterWebAuth2Options(
        useWebview: false,
        windowName: '_blank',
        debugOrigin: kIsWeb ? redirectUri.origin : null,
      ),
    );

    final Uri callbackUri = Uri.parse(callbackUrl);
    return flow.callback(_authorizationResponse(callbackUri));
  }

  Future<void> _startWebAuthentication({String? idpHint}) async {
    final AccessTokenResponse tokenResponse = await _webOAuth2Client()
        .getTokenWithAuthCodeFlow(
          clientId: _clientId,
          scopes: _scopes,
          authCodeParams: _authorizationParameters(idpHint),
        );

    _ensureValidWebTokenResponse(tokenResponse);
    _setWebTokenData(tokenResponse);
  }

  Future<void> _refreshWebToken() async {
    final String? refreshToken = _refreshTokenValue;
    if (_webTokenResponse == null || refreshToken == null) {
      return;
    }

    _startLoading();

    try {
      final AccessTokenResponse refreshedTokenResponse =
          await _webOAuth2Client().refreshToken(
            refreshToken,
            clientId: _clientId,
            scopes: _scopes,
          );
      if (refreshedTokenResponse.refreshToken == null ||
          refreshedTokenResponse.refreshToken!.isEmpty) {
        refreshedTokenResponse.refreshToken = refreshToken;
      }

      _ensureValidWebTokenResponse(refreshedTokenResponse);
      _setWebTokenData(refreshedTokenResponse);
    } catch (error) {
      _setError(error);
    } finally {
      _setLoading(false);
    }
  }

  Uri _redirectUri() {
    if (kIsWeb) {
      return Uri.parse(_webRedirectUrl);
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      return Uri.parse(_windowsRedirectUrl);
    }

    throw UnsupportedError('Plataforma nao suportada para autenticacao.');
  }

  Uri _postLogoutRedirectUri() {
    if (kIsWeb) {
      return Uri.parse('https://srv.ggwpcode.com.br/logout-success');
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      return Uri.parse('http://127.0.0.1:54322/logout-success');
    }

    throw UnsupportedError('Plataforma nao suportada para logout.');
  }

  Map<String, String> _authorizationParameters(String? idpHint) {
    return <String, String>{'prompt': 'login', ...?_idpHintParameters(idpHint)};
  }

  Map<String, String>? _idpHintParameters(String? idpHint) {
    final String? normalizedHint = _normalizedIdpHint(idpHint);
    if (normalizedHint == null) {
      return null;
    }

    return <String, String>{'kc_idp_hint': normalizedHint};
  }

  String? _normalizedIdpHint(String? idpHint) {
    final String? trimmedHint = idpHint?.trim();
    if (trimmedHint == null || trimmedHint.isEmpty) {
      return null;
    }

    return trimmedHint;
  }

  OAuth2Client _webOAuth2Client() {
    final Uri redirectUri = _redirectUri();

    return OAuth2Client(
      authorizeUrl: _authorizationEndpointUrl,
      tokenUrl: _tokenEndpointUrl,
      refreshUrl: _tokenEndpointUrl,
      redirectUri: redirectUri.toString(),
      customUriScheme: redirectUri.scheme,
    )..webAuthClient = createOAuth2WebAuth();
  }

  void _ensureValidWebTokenResponse(AccessTokenResponse tokenResponse) {
    if (tokenResponse.isValid() && tokenResponse.accessToken != null) {
      return;
    }

    throw StateError(_webTokenError(tokenResponse));
  }

  String _webTokenError(AccessTokenResponse tokenResponse) {
    final String? error = tokenResponse.error;
    final String? description = tokenResponse.errorDescription;

    if (error != null && description != null) {
      return '$error: $description';
    }

    if (error != null) {
      return error;
    }

    return 'Falha ao obter token OAuth2. HTTP ${tokenResponse.httpStatusCode}.';
  }

  Map<String, String> _authorizationResponse(Uri callbackUri) {
    final Map<String, String> response = <String, String>{
      ...callbackUri.queryParameters,
    };

    if (callbackUri.fragment.isNotEmpty) {
      response.addAll(Uri.splitQueryString(callbackUri.fragment));
    }

    return response;
  }

  void _setTokenData(oidc.TokenResponse tokenResponse) {
    final Map<String, dynamic> tokenJson = tokenResponse.toJson();
    final String? accessToken = tokenResponse.accessToken;
    final String? idToken = tokenJson['id_token'] as String?;
    final String? refreshToken = tokenResponse.refreshToken;
    final String? tokenType = tokenResponse.tokenType;
    final DateTime? expiresAt = tokenResponse.expiresAt;
    final List<String> scopes = _tokenScopes(tokenJson['scope']);

    final Map<String, Object?> authData = <String, Object?>{
      'accessToken': accessToken,
      'idToken': idToken,
      if (refreshToken != null && refreshToken.isNotEmpty)
        'refreshToken': refreshToken,
      'tokenType': tokenType,
      'expiresAt': expiresAt?.toIso8601String(),
      'scopes': scopes,
      'idTokenClaims': _decodeJwt(idToken),
      'accessTokenClaims': _decodeJwt(accessToken),
    };

    _refreshTokenValue = refreshToken;
    _idTokenValue = idToken;
    _authJson = const JsonEncoder.withIndent('  ').convert(authData);
    _errorMessage = null;
    _notifyListeners();
  }

  void _setWebTokenData(AccessTokenResponse tokenResponse) {
    final String? accessToken = tokenResponse.accessToken;
    final String? idToken = _stringTokenField(tokenResponse, 'id_token');
    final String? refreshToken = tokenResponse.refreshToken;
    final List<String> scopes =
        tokenResponse.scope
            ?.where((String scope) => scope.isNotEmpty)
            .toList() ??
        _scopes;

    final Map<String, Object?> authData = <String, Object?>{
      'accessToken': accessToken,
      'idToken': idToken,
      if (refreshToken != null && refreshToken.isNotEmpty)
        'refreshToken': refreshToken,
      'tokenType': tokenResponse.tokenType,
      'expiresAt': tokenResponse.expirationDate?.toIso8601String(),
      'scopes': scopes,
      'idTokenClaims': _decodeJwt(idToken),
      'accessTokenClaims': _decodeJwt(accessToken),
    };

    _credential = null;
    _webTokenResponse = tokenResponse;
    _refreshTokenValue = refreshToken;
    _idTokenValue = idToken;
    _authJson = const JsonEncoder.withIndent('  ').convert(authData);
    _errorMessage = null;
    _notifyListeners();
  }

  String? _stringTokenField(
    AccessTokenResponse tokenResponse,
    String fieldName,
  ) {
    final Object? value = tokenResponse.getRespField(fieldName);
    if (value is String && value.isNotEmpty) {
      return value;
    }

    return null;
  }

  List<String> _tokenScopes(Object? scope) {
    if (scope is String && scope.trim().isNotEmpty) {
      return scope
          .split(' ')
          .where((String value) => value.isNotEmpty)
          .toList();
    }

    if (scope is List) {
      return scope.whereType<String>().toList();
    }

    return _scopes;
  }

  Map<String, dynamic>? _decodeJwt(String? token) {
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      return JwtDecoder.decode(token);
    } catch (_) {
      return null;
    }
  }

  void _startLoading() {
    _isLoading = true;
    _errorMessage = null;
    _notifyListeners();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;
    _notifyListeners();
  }

  void _setError(Object error) {
    _errorMessage = _friendlyErrorMessage(error);
    _notifyListeners();
  }

  void _clearLocalSession() {
    _authJson = null;
    _credential = null;
    _webTokenResponse = null;
    _refreshTokenValue = null;
    _idTokenValue = null;
    _errorMessage = null;
    _isLoading = false;
    _notifyListeners();
  }

  String _friendlyErrorMessage(Object error) {
    final String message = error.toString();
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        (message.contains('SocketException') ||
            message.contains('Callback url scheme must start'))) {
      return 'Nao foi possivel abrir o callback local do Windows.\n'
          'Verifique se a porta 1234 esta livre e se o redirect '
          '$_windowsRedirectUrl esta cadastrado no Keycloak.\n'
          'A porta local pode estar ocupada, bloqueada ou reservada.';
    }

    if (kIsWeb &&
        (message.contains('Failed to fetch') ||
            message.contains('XMLHttpRequest error'))) {
      return 'O navegador bloqueou uma chamada para o Keycloak.\n'
          'No client $_clientId do Keycloak, confira Web Origins e Valid '
          'Redirect URIs para a origem do app Web, como $_webRedirectUrl.';
    }

    return message;
  }

  void _notifyListeners() {
    if (_isDisposed) {
      return;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
