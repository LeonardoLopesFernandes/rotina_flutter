import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rotina_comercial/components/animated_logo_title.dart';
import 'package:rotina_comercial/api/client.dart'
    show setAuthToken, clearToken, getAuthToken;
import 'package:rotina_comercial/api/endpoints.dart' show getItems;
import 'package:rotina_comercial/auth/auth_provider.dart';
import 'package:rotina_comercial/storage/session.dart';
import 'package:rotina_comercial/theme.dart';
import 'package:rotina_comercial/utils/time.dart' show formatApiDate;
import 'package:rotina_comercial/utils/toast.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = true;
  bool _autoLoginDisparado = false;
  bool _obscurePassword = true;
  bool _waitingBrowserReturn = false;
  bool _validatingToken = false;
  String _clipboardHash = '';
  DateTime? _browserOpenedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed && _waitingBrowserReturn) {
      await _checkClipboardForToken();
    }
  }

  Future<void> _init() async {
    final savedEmail = await Session.getSavedEmail();
    final savedPassword = await Session.getSavedPassword();
    _emailController.text = savedEmail;
    _passwordController.text = savedPassword;
    setState(() => _loading = false);

    final hasCreds = await Session.hasSavedCredentials();
    if (hasCreds && !_autoLoginDisparado) {
      await Future.delayed(const Duration(milliseconds: 2500));
      if (mounted && !_autoLoginDisparado) {
        _autoLoginDisparado = true;
        Navigator.of(context)
            .pushNamed('LoginWebView', arguments: {'autoLogin': true});
      }
    }
  }

  Future<void> _saveCredentials() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isNotEmpty && password.isNotEmpty) {
      await Session.saveCredentials(email, password);
    }
  }

  void _handleLogin() {
    _autoLoginDisparado = true;
    Navigator.of(context)
        .pushNamed('LoginWebView', arguments: {'autoLogin': false});
  }

  Future<void> _handleOpenBrowser() async {
    _saveCredentials();
    final url =
        'https://sl-authorization.americanas.io/rotina-comercial'
        '?redirect_uri=rotina://auth';
    try {
      // Salva hash do clipboard antes de abrir o navegador
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      _clipboardHash = data?.text ?? '';
      _browserOpenedAt = DateTime.now();
      _waitingBrowserReturn = true;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      showToast('Faça login no navegador. Ao concluir, volte ao app.');
    } catch (e) {
      _waitingBrowserReturn = false;
      showToast('Não foi possível abrir o navegador: $e', isError: true);
    }
  }

  Future<void> _checkClipboardForToken() async {
    if (_validatingToken) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final clipboardText = data?.text ?? '';
      if (clipboardText.isEmpty || clipboardText == _clipboardHash) return;

      // Verifica se parece um token JWT (muito longo, começa com ey)
      String token = clipboardText.trim();
      if (token.toLowerCase().startsWith('bearer ')) {
        token = token.substring(7).trim();
      }
      // Cookie header
      final cookieIdx = token.indexOf('rc-newToken=');
      if (cookieIdx >= 0) {
        var value = token.substring(cookieIdx + 'rc-newToken='.length);
        final sep = value.indexOf(RegExp(r'[;&]'));
        if (sep >= 0) value = value.substring(0, sep);
        token = value.trim();
      }
      // URL com ?token=...
      if (token.contains('token=')) {
        final qi = token.indexOf('token=');
        var value = token.substring(qi + 'token='.length);
        final amp = value.indexOf(RegExp(r'[&\s]'));
        if (amp >= 0) value = value.substring(0, amp);
        token = Uri.decodeComponent(value).trim();
      }

      if (token.length < 50) return;
      // Valida formato JWT básico
      if (!token.contains('.')) return;

      // Evita reprocessar o mesmo token
      if (token == _clipboardHash) return;
      _clipboardHash = token;

      await _validateAndLogin(token);
    } catch (_) {}
  }

  Future<void> _validateAndLogin(String token) async {
    if (_validatingToken) return;
    _validatingToken = true;
    setState(() {});
    showToast('Token detectado! Validando...');
    try {
      setAuthToken(token);
      await getItems(formatApiDate(DateTime.now()));
      if (!mounted) return;
      await context.read<AuthProvider>().setAuthenticated(token);
      // Extrair e salvar nome do usuario
      final name = _extractNameFromToken(token);
      if (name.isNotEmpty) {
        await context.read<AuthProvider>().setUserName(name);
      }
      _waitingBrowserReturn = false;
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on DioException catch (e) {
      clearToken();
      _validatingToken = false;
      final status = e.response?.statusCode;
      if (status == 403 || status == 401) {
        showToast(
            'Token detectado mas rejeitado (HTTP $status). '
            'Tente copiar o token novamente no navegador.',
            isError: true);
      } else {
        showToast('Erro ao validar token: ${mapErrorMessage(e)}', isError: true);
      }
    } catch (e) {
      clearToken();
      _validatingToken = false;
      showToast('Token detectado mas não foi possível validar.', isError: true);
    }
  }

  static String mapErrorMessage(Object error) {
    final message =
        error is DioException ? error.message ?? 'Erro' : error.toString();
    if (message.contains('conexão') || message.contains('Connection')) {
      return 'Sem conexão com a internet.';
    }
    return message;
  }

  static String _extractNameFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return '';
      String payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');
      final decoded = utf8.decode(base64.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final user = map['user'];
      if (user != null && user is Map) {
        return user['nome'] ?? '';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final focus = FocusManager.instance.primaryFocus;
        if (focus != null && focus.hasFocus) {
          focus.unfocus();
          return;
        }
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AnimatedLogoTitle(
                  logoSize: 110,
                  title: 'Rotina Comercial',
                  titleColor: AppColors.primary,
                ),
                const SizedBox(height: 32),
                const Text(
                  'americanas.io',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Open Sans',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (_validatingToken)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        ),
                        SizedBox(width: 10),
                        Text('Validando token...',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                fontFamily: 'Open Sans')),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      elevation: 2,
                    ),
                    onPressed: _handleLogin,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _MicrosoftLogo(size: 20),
                        SizedBox(width: 10),
                        Text('Login Microsoft',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                fontFamily: 'Open Sans')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _browserButton() {
    final isWaiting = _waitingBrowserReturn;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isWaiting ? AppColors.primary.withOpacity(0.8) : AppColors.buttonSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          elevation: 1,
        ),
        icon: Icon(
          isWaiting ? Icons.hourglass_top_rounded : Icons.open_in_browser,
          color: Colors.white,
          size: 20,
        ),
        label: Text(
          isWaiting ? 'Volte ao app apos o login...' : 'ENTRAR VIA NAVEGADOR',
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              fontFamily: 'Open Sans'),
        ),
        onPressed: isWaiting ? null : _handleOpenBrowser,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          color: Color(0xFFB3B3B3), fontFamily: 'Open Sans', fontSize: 16),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFC8C6C4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFC8C6C4)),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          elevation: 2,
        ),
        onPressed: onPressed,
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                fontFamily: 'Open Sans')),
      ),
    );
  }

  Widget _secondaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.buttonSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          elevation: 1,
        ),
        onPressed: onPressed,
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                fontFamily: 'Open Sans')),
      ),
    );
  }
}

/// Logo 2x2 da Microsoft (4 quadrados coloridos).
class _MicrosoftLogo extends StatelessWidget {
  final double size;
  const _MicrosoftLogo({this.size = 20});

  @override
  Widget build(BuildContext context) {
    final c = size / 2 - 1;
    final tiles = [
      Container(color: const Color(0xFFF25022)),
      Container(color: const Color(0xFF7FBA00)),
      Container(color: const Color(0xFF00A4EF)),
      Container(color: const Color(0xFFFFBA08)),
    ];
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        children: [
          Row(children: [
            SizedBox(width: c, height: c, child: tiles[0]),
            const SizedBox(width: 2),
            SizedBox(width: c, height: c, child: tiles[1]),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            SizedBox(width: c, height: c, child: tiles[2]),
            const SizedBox(width: 2),
            SizedBox(width: c, height: c, child: tiles[3]),
          ]),
        ],
      ),
    );
  }
}
