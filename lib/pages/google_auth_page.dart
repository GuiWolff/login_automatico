import 'package:flutter/material.dart';
import 'package:login_automatico/pages/google_auth_page_controller.dart';

const Color _pageBackgroundColor = Color(0xFF151818);
const Color _cardBackgroundColor = Color(0xFF1B1D1D);
const Color _buttonBackgroundColor = Color(0xFF202020);
const Color _buttonBorderColor = Color(0xFF343434);
const Color _primaryTextColor = Color(0xFFF6F6F2);
const Color _secondaryTextColor = Color(0xFFB8BBB5);
const Color _mutedTextColor = Color(0xFF8C918B);

class KeycloakAuthPage extends StatefulWidget {
  const KeycloakAuthPage({super.key});

  @override
  State<KeycloakAuthPage> createState() => _KeycloakAuthPageState();
}

class _KeycloakAuthPageState extends State<KeycloakAuthPage> {
  late final GoogleAuthPageController _controller;
  String? _lastSnackBarError;

  @override
  void initState() {
    super.initState();
    _controller = GoogleAuthPageController();
    _controller.addListener(_showErrorSnackBar);
  }

  @override
  void dispose() {
    _controller.removeListener(_showErrorSnackBar);
    _controller.dispose();
    super.dispose();
  }

  void _showErrorSnackBar() {
    final String? errorMessage = _controller.errorMessage;
    if (errorMessage == null) {
      _lastSnackBarError = null;
      return;
    }

    if (errorMessage == _lastSnackBarError) {
      return;
    }

    _lastSnackBarError = errorMessage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller.errorMessage != errorMessage) {
        return;
      }

      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(errorMessage)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return _GoogleAuthPageView(controller: _controller);
      },
    );
  }
}

class _GoogleAuthPageView extends StatelessWidget {
  const _GoogleAuthPageView({required this.controller});

  final GoogleAuthPageController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _cardBackgroundColor,
                  border: Border.all(color: _buttonBorderColor),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 32,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _LogoHeader(),
                      const SizedBox(height: 32),
                      const Text(
                        'Acesse sua conta',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _primaryTextColor,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Escolha uma forma de login para continuar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _secondaryTextColor,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (controller.isLoading) ...<Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            minHeight: 3,
                            backgroundColor: _buttonBackgroundColor,
                            color: _primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _LoginButton(
                        icon: Icons.g_mobiledata,
                        iconColor: const Color(0xFFEA4335),
                        label: 'Entrar com Google',
                        onPressed: controller.canLogin
                            ? () => controller.loginWithProvider('google')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _LoginButton(
                        icon: Icons.apple,
                        iconColor: _primaryTextColor,
                        label: 'Entrar com Apple',
                        onPressed: controller.canLogin
                            ? () => controller.loginWithProvider('apple')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _LoginButton(
                        icon: Icons.facebook,
                        iconColor: const Color(0xFF1877F2),
                        label: 'Entrar com Facebook',
                        onPressed: controller.canLogin
                            ? () => controller.loginWithProvider('facebook')
                            : null,
                      ),
                      const SizedBox(height: 18),
                      const _DividerWithText(label: 'ou'),
                      const SizedBox(height: 18),
                      _LoginButton(
                        icon: Icons.email_outlined,
                        iconColor: _primaryTextColor,
                        label: 'Entrar com e-mail',
                        onPressed: controller.canLogin
                            ? controller.loginWithEmail
                            : null,
                      ),
                      if (!controller.isSupportedPlatform) ...<Widget>[
                        const SizedBox(height: 18),
                        _MessageBox(
                          message: controller.unsupportedPlatformMessage,
                          backgroundColor: const Color(0xFF332727),
                          foregroundColor: const Color(0xFFFFC9C9),
                        ),
                      ],
                      if (controller.errorMessage != null) ...<Widget>[
                        const SizedBox(height: 18),
                        _MessageBox(
                          message: controller.errorMessage!,
                          backgroundColor: const Color(0xFF332727),
                          foregroundColor: const Color(0xFFFFC9C9),
                        ),
                      ],
                      if (controller.hasAuthData) ...<Widget>[
                        const SizedBox(height: 18),
                        const _MessageBox(
                          message:
                              'Autenticacao concluida pelo Keycloak. Nenhuma senha foi coletada pelo app.',
                          backgroundColor: Color(0xFF183127),
                          foregroundColor: Color(0xFFC6F6D5),
                        ),
                        if (controller.hasRefreshToken) ...<Widget>[
                          const SizedBox(height: 12),
                          _SessionActionButton(
                            icon: Icons.refresh,
                            label: 'Atualizar token',
                            onPressed: controller.isLoading
                                ? null
                                : controller.refreshToken,
                          ),
                        ],
                        const SizedBox(height: 8),
                        _SessionActionButton(
                          icon: Icons.logout,
                          label: 'Sair',
                          onPressed: controller.isLoading
                              ? null
                              : () => controller.signOut(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        'Ao continuar, voce concorda com os Termos de Uso e a Politica de Privacidade.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _mutedTextColor,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: _buttonBackgroundColor,
            border: Border.all(color: _buttonBorderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: Text(
                'A',
                style: TextStyle(
                  color: _primaryTextColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'ARGO',
              style: TextStyle(
                color: _primaryTextColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'sistemas',
              style: TextStyle(
                color: _secondaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: _buttonBackgroundColor,
          foregroundColor: _primaryTextColor,
          disabledForegroundColor: _mutedTextColor,
          side: const BorderSide(color: _buttonBorderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              color: isDisabled ? _mutedTextColor : iconColor,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 38),
          ],
        ),
      ),
    );
  }
}

class _DividerWithText extends StatelessWidget {
  const _DividerWithText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider(color: _buttonBorderColor, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              color: _mutedTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(child: Divider(color: _buttonBorderColor, height: 1)),
      ],
    );
  }
}

class _SessionActionButton extends StatelessWidget {
  const _SessionActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          backgroundColor: _buttonBackgroundColor,
          foregroundColor: _primaryTextColor,
          disabledForegroundColor: _mutedTextColor,
          side: const BorderSide(color: _buttonBorderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
