# Contexto
Você é um desenvolvedor Senior em Flutter/Dart.

# Descrição
Atualmente existe uma tela `GoogleAuthPage` usando o pacote `google_sign_in` para autenticar diretamente no Google.

Quero trocar esse fluxo para autenticação via Keycloak.

O fluxo correto deve ser:

Flutter
→ Keycloak
→ Google como Identity Provider
→ Keycloak
→ Flutter recebe token do Keycloak

O Keycloak já está configurado em:

Issuer:
https://open-id.ggwpcode.com.br/realms/empresa-abc

Realm:
empresa-abc

O Google já foi adicionado no Keycloak como Identity Provider.

# Objetivo
Substituir a autenticação direta com Google por autenticação OpenID Connect usando Keycloak.

O botão pode se chamar:

Entrar com Keycloak

ou:

Entrar

Ao clicar, deve abrir o fluxo do Keycloak. Dentro do Keycloak o usuário poderá escolher login com Google.

Após autenticar, a tela deve exibir em JSON os dados retornados:

- accessToken
- idToken
- refreshToken
- accessTokenExpirationDateTime
- tokenType
- scopes
- claims decodificadas do idToken
- claims decodificadas do accessToken, se possível

# Pacote
Usar o pacote:

flutter_appauth

Esse pacote comunica com provedores OAuth2/OpenID Connect, como Keycloak.

Adicionar no pubspec.yaml:

flutter_appauth: ^8.0.3
jwt_decoder: ^2.0.1

Se já houver versões compatíveis, não forçar downgrade.

# Arquivos
Alterar o mínimo necessário.

Arquivo atual:
@file:google_auth_page.dart

Pode renomear a tela para:

keycloak_auth_page.dart

ou manter o nome atual se for mais simples.

# Configuração Keycloak
Usar constantes no arquivo por enquanto:

```dart
static const String _issuer =
    'https://open-id.ggwpcode.com.br/realms/empresa-abc';

static const String _clientId = 'flutter-app';

static const String _redirectUrl = 'com.ggwpcode.auth:/callback';

static const String _postLogoutRedirectUrl = 'com.ggwpcode.auth:/callback';

static const List<String> _scopes = <String>[
  'openid',
  'profile',
  'email',
  'offline_access',
];

Importante

Se o client flutter-app ainda não existir no Keycloak, deixar comentário no código explicando que ele precisa ser criado em:

Keycloak
→ realm empresa-abc
→ Clients
→ Create client

Configuração sugerida do client:

Client ID: flutter-app
Client type: OpenID Connect
Client authentication: Off
Standard flow: On
Direct access grants: Off
Valid redirect URIs:
com.ggwpcode.auth:/callback
Valid post logout redirect URIs:
com.ggwpcode.auth:/callback
Web origins:
*
Implementação esperada

Criar uma tela StatefulWidget com:

botão "Entrar com Keycloak"
botão "Sair", quando autenticado
loading
mensagem de erro
área com JSON formatado

Usar:

final FlutterAppAuth _appAuth = const FlutterAppAuth();

final AuthorizationTokenResponse? result =
    await _appAuth.authorizeAndExchangeCode(
  AuthorizationTokenRequest(
    _clientId,
    _redirectUrl,
    issuer: _issuer,
    scopes: _scopes,
    promptValues: ['login'],
  ),
);

{
  'tokenType': result.tokenType,
  'accessToken': result.accessToken,
  'idToken': result.idToken,
  'refreshToken': result.refreshToken,
  'accessTokenExpirationDateTime':
      result.accessTokenExpirationDateTime?.toIso8601String(),
  'scopes': result.scopes,
  'idTokenClaims': ...,
  'accessTokenClaims': ...,
}

Para decodificar claims, usar JwtDecoder.decode(token) com try/catch.

Refresh token:

Implementar método _refreshToken() que use:

_appAuth.token(
  TokenRequest(
    _clientId,
    _redirectUrl,
    issuer: _issuer,
    refreshToken: _refreshTokenValue,
    scopes: _scopes,
  ),
);

Logout:

Implementar método _logout() limpando os tokens locais da tela.

Se o pacote oferecer suporte a endSession para a plataforma atual, usar EndSessionRequest. Se ficar complexo ou incompatível, apenas limpar estado local e deixar comentário TODO para logout federado no Keycloak.

UI

A tela deve conter:

AppBar: "Keycloak Auth"
Botão: "Entrar com Keycloak"
Botão: "Atualizar token", se houver refreshToken
Botão: "Sair", se autenticado
JSON em SelectableText
Fonte monoespaçada
Erros em destaque
Regras
Remover o uso direto de google_sign_in desta tela.
Não usar Firebase.
Não salvar tokens em storage ainda.
Não criar backend.
Não criar arquitetura complexa.
Não reescrever arquivos inteiros desnecessariamente, exceto se for inevitável para substituir a tela.
Manter UTF-8.
Código deve compilar.
Se precisar alterar AndroidManifest, fazer somente o necessário para o redirect scheme.
Se precisar alterar rotas, fazer a menor alteração possível.
Android

Se necessário, configurar callback no AndroidManifest.xml.

Adicionar intent-filter compatível com:

scheme:
com.ggwpcode.auth

callback:
com.ggwpcode.auth:/callback

Entregáveis
Substituir a tela de login Google direto por login via Keycloak.
Exibir JSON dos tokens e claims na tela.
Adicionar refresh token.
Adicionar logout local.
Atualizar pubspec.yaml.
Salvar um resumo da execução com nome datado e sufixo -resumo.
Rodar o script @file:base-prompt-tarefas.md com o [NOME_DA_PASTA] já definido.