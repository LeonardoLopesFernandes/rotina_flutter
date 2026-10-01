import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:rotina_comercial/api/client.dart'
    show setAuthToken, clearToken, mapErrorMessage;
import 'package:rotina_comercial/api/endpoints.dart' show getItems;
import 'package:rotina_comercial/auth/auth_provider.dart';
import 'package:rotina_comercial/theme.dart';
import 'package:rotina_comercial/utils/time.dart' show formatApiDate;
import 'package:rotina_comercial/utils/toast.dart';
import 'package:provider/provider.dart';

class LoginTokenScreen extends StatefulWidget {
  const LoginTokenScreen({super.key});

  @override
  State<LoginTokenScreen> createState() => _LoginTokenScreenState();
}

class _LoginTokenScreenState extends State<LoginTokenScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  String _extractToken(String raw) {
    var text = raw.trim();
    if (text.toLowerCase().startsWith('bearer ')) {
      text = text.substring(7).trim();
    }
    // Cookie header, ex: "rc-newToken=eyJ...; outras=..."
    final cookieIdx = text.indexOf('rc-newToken=');
    if (cookieIdx >= 0) {
      var value = text.substring(cookieIdx + 'rc-newToken='.length);
      final sep = value.indexOf(RegExp(r'[;&]'));
      if (sep >= 0) value = value.substring(0, sep);
      return value.trim();
    }
    // URL com ?token=... ou &token=...
    final qi = text.indexOf('token=');
    if (qi >= 0) {
      var value = text.substring(qi + 'token='.length);
      final amp = value.indexOf(RegExp(r'[&\s]'));
      if (amp >= 0) value = value.substring(0, amp);
      value = Uri.decodeComponent(value);
      return value.trim();
    }
    return text;
  }

  Future<void> _handleEnter() async {
    final token = _extractToken(_controller.text);
    if (token.isEmpty) {
      showToast('Cole a URL ou o token');
      return;
    }
    if (token.length <= 20) {
      showToast('Token muito curto. Use o token rc-newToken completo.', isError: true);
      return;
    }
    setState(() => _saving = true);
    showToast('Validando token...');
    try {
      setAuthToken(token);
      await getItems(formatApiDate(DateTime.now()));
      await context.read<AuthProvider>().setAuthenticated(token);
      // Extract and save user name from JWT
      final name = _extractNameFromToken(token);
      if (name.isNotEmpty) {
        await context.read<AuthProvider>().setUserName(name);
      }
      // LoginToken foi empurrado sobre a Root; ao autenticar, a Root já
      // exibe a Home, mas esta tela ficaria por cima. Fazemos pop à raiz.
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on DioException catch (e) {
      clearToken();
      final status = e.response?.statusCode;
      if (status == 403 || status == 401) {
        final body = (e.response?.data?.toString() ?? '').replaceAll('\n', ' ');
        debugPrint('TOKEN_VALIDATION_FAILED status=$status body=$body');
        showToast(
            'Token rejeitado (HTTP $status). Se a rede usa proxy, ele pode '
            'estar bloqueando o app. Use o navegador (Kiwi) para pegar o '
            'token e cole aqui. Detalhe: ${body.length > 80 ? body.substring(0, 80) : body}',
            isError: true);
      } else if (status == 500) {
        showToast('Erro no servidor (500). Tente novamente.', isError: true);
      } else {
        showToast(mapErrorMessage(e), isError: true);
      }
      if (mounted) setState(() => _saving = false);
    } catch (e) {
      clearToken();
      showToast('Não foi possível validar o token.', isError: true);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Entrar com token',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo_rotina.png', width: 80, height: 80),
            const SizedBox(height: 16),
            const Text(
              'Cole a URL retornada ou o token de acesso',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'https://...?token=xxx  ou  cole o token direto',
                hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: _saving ? null : _handleEnter,
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ENTRAR',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
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
}
