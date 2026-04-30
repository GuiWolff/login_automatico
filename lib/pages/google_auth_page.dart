import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:login_automatico/service/oauth2_web_auth.dart';
import 'package:oauth2_client/access_token_response.dart';
import 'package:oauth2_client/oauth2_client.dart';
import 'package:openid_client/openid_client.dart' as oidc;

class KeycloakAuthPage extends StatefulWidget {
  const KeycloakAuthPage({super.key});

  @override
  State<KeycloakAuthPage> createState() => _KeycloakAuthPageState();
}

class _KeycloakAuthPageState extends State<KeycloakAuthPage> {
  static const String _issuerUrl = 'https://open-id.ggwpcode.com.br/realms/empresa-abc';

  static const String _authorizationEndpointUrl =
      '$_issuerUrl/protocol/openid-connect/auth';

  static const String _tokenEndpointUrl =
      '$_issuerUrl/protocol/openid-connect/token';

  static const String _clientId = 'login_automatico';

  static const String _windowsRedirectUrl = 'http://127.0.0.1:54322/callback';

  static const String _webRedirectUrl = 'https://srv.ggwpcode.com.br/callback';

  static const List<String> _scopes = <String>[
    'openid',
    'profile',
    'email',
    'offline_access',
  ];

  bool _isLoading = false;
  String? _errorMessage;
  String? _authJson;
  oidc.Credential? _credential;
  AccessTokenResponse? _webTokenResponse;
  String? _refreshTokenValue;

  bool get _isSupportedPlatform =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.windows;

  String get _unsupportedPlatformMessage =>
      'Esta tela esta configurada para autenticar via Keycloak em Flutter Web '
      'ou Flutter Windows.';

  Uri _redirectUri() {
    if (kIsWeb) {
      return Uri.parse(_webRedirectUrl);
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      return Uri.parse(_windowsRedirectUrl);
    }

    throw UnsupportedError('Plataforma nao suportada para autenticacao.');
  }

  Future<void> _signIn() async {
    if (!_isSupportedPlatform) {
      _setError(_unsupportedPlatformMessage);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kIsWeb) {
        await _startWebAuthentication();
        return;
      }

      final oidc.Credential credential = await _authenticateWindows();
      final oidc.TokenResponse tokenResponse = await credential
          .getTokenResponse();

      _credential = credential;
      _webTokenResponse = null;
      _setTokenData(tokenResponse);
    } catch (error) {
      _setError(error);
      if (kIsWeb && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } finally {
      if (!kIsWeb && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<oidc.Credential> _authenticateWindows() async {
    final oidc.Issuer issuer = await oidc.Issuer.discover(
      Uri.parse(_issuerUrl),
    );
    final oidc.Client client = oidc.Client(issuer, _clientId);
    final Uri redirectUri = _redirectUri();

    final oidc.Flow flow = oidc.Flow.authorizationCodeWithPKCE(
      client,
      scopes: _scopes,
      prompt: 'login',
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

  Future<void> _startWebAuthentication() async {
    final AccessTokenResponse tokenResponse = await _webOAuth2Client()
        .getTokenWithAuthCodeFlow(
          clientId: _clientId,
          scopes: _scopes,
          authCodeParams: const <String, dynamic>{'prompt': 'login'},
        );

    _ensureValidWebTokenResponse(tokenResponse);
    _setWebTokenData(tokenResponse);
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

  Future<void> _refreshToken() async {
    if (kIsWeb) {
      await _refreshWebToken();
      return;
    }

    final oidc.Credential? credential = _credential;
    if (credential == null || _refreshTokenValue == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final oidc.TokenResponse tokenResponse = await credential
          .getTokenResponse(true);
      _setTokenData(tokenResponse);
    } catch (error) {
      _setError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshWebToken() async {
    final String? refreshToken = _refreshTokenValue;
    if (_webTokenResponse == null || refreshToken == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _signOut() {
    setState(() {
      _authJson = null;
      _credential = null;
      _webTokenResponse = null;
      _refreshTokenValue = null;
      _errorMessage = null;
    });
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

    if (!mounted) {
      return;
    }

    setState(() {
      _refreshTokenValue = refreshToken;
      _authJson = const JsonEncoder.withIndent('  ').convert(authData);
      _errorMessage = null;
    });
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

    if (!mounted) {
      return;
    }

    setState(() {
      _credential = null;
      _webTokenResponse = tokenResponse;
      _refreshTokenValue = refreshToken;
      _authJson = const JsonEncoder.withIndent('  ').convert(authData);
      _errorMessage = null;
      _isLoading = false;
    });
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

  void _setError(Object error) {
    if (!mounted) {
      return;
    }

    final String message = _friendlyErrorMessage(error);
    setState(() {
      _errorMessage = message;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(message)));
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final bool hasAuthData = _authJson != null;
    final bool hasRefreshToken = _refreshTokenValue != null;
    final bool isSupportedPlatform = _isSupportedPlatform;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keycloak Auth'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_isLoading) const LinearProgressIndicator(),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isLoading ? null : _signIn,
                icon: const Icon(Icons.login),
                label: const Text('Entrar com Keycloak'),
              ),
              if (!isSupportedPlatform) ...<Widget>[
                const SizedBox(height: 16),
                _MessageBox(
                  message: _unsupportedPlatformMessage,
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onErrorContainer,
                ),
              ],
              if (hasAuthData) ...<Widget>[
                const SizedBox(height: 8),
                if (hasRefreshToken) ...<Widget>[
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _refreshToken,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Atualizar token'),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair'),
                ),
              ],
              if (_errorMessage != null) ...<Widget>[
                const SizedBox(height: 16),
                _MessageBox(
                  message: _errorMessage!,
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onErrorContainer,
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      _authJson ?? 'Nenhum usuario autenticado.',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, style: TextStyle(color: foregroundColor)),
      ),
    );
  }
}
