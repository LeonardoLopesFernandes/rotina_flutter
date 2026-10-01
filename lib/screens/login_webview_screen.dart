import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:rotina_comercial/auth/auth_provider.dart';
import 'package:rotina_comercial/storage/session.dart';
import 'package:rotina_comercial/theme.dart';
import 'package:rotina_comercial/utils/toast.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _loginUrl = 'https://sl-authorization.americanas.io/rotina-comercial';

const String _appBase = 'https://rotina-comercial.americanas.io';

String _jsString(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n').replaceAll('\r', '');

String _buildAutoFillScript(String email, String password) {
  final e = _jsString(email);
  final p = _jsString(password);
  return '(function(){'
      'function post(status){window.ReactNativeWebView.postMessage(JSON.stringify({type:"AUTOFILL",status:status}));}'
      'function setV(el,v){var d=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,"value");if(d&&d.set){d.set.call(el,v);}el.dispatchEvent(new Event("input",{bubbles:true}));el.dispatchEvent(new Event("change",{bubbles:true}));}'
      'var em=document.getElementById("i0116");'
      'if(em){setV(em,"$e");var b1=document.getElementById("idSIButton9");if(b1){b1.click();post("email-clicked");}else{post("email-no-btn");}return;}'
      'var pw=document.getElementById("i0118");'
      'if(pw){setV(pw,"$p");var b2=document.getElementById("idSIButton9");if(b2){b2.click();post("pwd-clicked");}else{post("pwd-no-btn");}return;}'
      'var km=document.getElementById("KmsiCheckboxField");'
      'if(km){var b3=document.getElementById("idSIButton9");if(b3){b3.click();post("kmsi-clicked");}else{post("kmsi-no-btn");}return;}'
      'post("no-field");'
      '})();'
      'true;';
}

const String _captureTokenScript = '(function(){'
    'try{'
    'var t="";'
    'var cookies=document.cookie?document.cookie.split("; "):[];'
    'for(var i=0;i<cookies.length;i++){var kv=cookies[i].split("=");if(kv[0]==="rc-newToken"){t=kv.slice(1).join("=");}}'
    'if(!t&&window.localStorage){try{t=window.localStorage.getItem("rc-newToken")||"";}catch(e){}}'
    'if(!t&&window.sessionStorage){try{t=window.sessionStorage.getItem("rc-newToken")||"";}catch(e){}}'
    'if(t&&t!=="null"&&t!=="undefined"&&t.length>50){'
    'window.ReactNativeWebView.postMessage(JSON.stringify({type:"TOKEN",token:t}));'
    '}'
    '}catch(e){}'
    '})();'
    'true;';

const String _captureUsernameScript = '(function(){'
    'try{'
    'var sels=[".user-name",".userName",".user-info",".user",".user-name",".userName",".profile-name",".profileName",".header-user",".headerUser",".logged-user",".loggedUser","#user-name","#userName","#user",".nome-usuario",".usuario-logado"];'
    'var name="";'
    'for(var i=0;i<sels.length;i++){var el=document.querySelector(sels[i]);if(el&&el.textContent&&el.textContent.trim()){name=el.textContent.trim();break;}}'
    'if(!name&&window.localStorage){name=window.localStorage.getItem("userName")||window.localStorage.getItem("user_name")||"";}'
    'if(!name&&window.sessionStorage){name=window.sessionStorage.getItem("userName")||"";}'
    'if(name&&name!=="null"&&name!=="undefined"){'
    'window.ReactNativeWebView.postMessage(JSON.stringify({type:"USERNAME",name:name}));'
    '}'
    '}catch(e){}'
    '})();'
    'true;';

String? _getQueryToken(String url) {
  if (!url.startsWith(_appBase)) return null;
  final qi = url.indexOf('?');
  if (qi < 0) return null;
  final query = url.substring(qi + 1);
  for (final pair in query.split('&')) {
    final eq = pair.indexOf('=');
    if (eq > 0 && pair.substring(0, eq) == 'token') {
      final value = Uri.decodeComponent(pair.substring(eq + 1));
      if (value.isNotEmpty && value.length > 50) return value;
    }
  }
  return null;
}

class LoginWebViewScreen extends StatefulWidget {
  const LoginWebViewScreen({super.key});

  @override
  State<LoginWebViewScreen> createState() => _LoginWebViewScreenState();
}

class _LoginWebViewScreenState extends State<LoginWebViewScreen> {
  late final WebViewController _webViewController;
  bool _autoLogin = false;
  bool _loginDone = false;
  bool _tokenFound = false;
  int _tokenAttempts = 0;
  String _currentUrl = '';
  String _email = '';
  String _password = '';
  final List<Timer> _timers = [];
  bool _loading = true;
  String _loadingText = 'Aguarde...';

  @override
  void initState() {
    super.initState();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    _autoLogin = args != null && (args['autoLogin'] == true);

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            _onNavigation(request.url);
            return NavigationDecision.navigate;
          },
          onPageFinished: (url) {
            _onLoadEnd(url);
          },
          onWebResourceError: (error) {
            if (_loginDone) return;
            if (error.isForMainFrame == true) {
              final desc = error.description.toLowerCase();
              if (desc.contains('connection_refused') ||
                  desc.contains('err_connection_refused') ||
                  desc.contains('name not resolved') ||
                  desc.contains('internet') ||
                  desc.contains('dns')) {
                showToast(
                    'Não foi possível abrir o login da Microsoft. Sua rede '
                    'pode estar bloqueando o acesso. Use "Entrar com token".',
                    isError: true);
              } else {
                showToast('Erro ao carregar: ${error.description}', isError: true);
              }
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'ReactNativeWebView',
        onMessageReceived: (message) => _onMessage(message.message),
      );

    _prepareAutoLogin();
    _webViewController.loadRequest(Uri.parse(_loginUrl));
  }

  Future<void> _prepareAutoLogin() async {
    if (_autoLogin) {
      final email = await Session.getSavedEmail();
      final password = await Session.getSavedPassword();
      if (email.trim().isEmpty || password.trim().isEmpty) {
        _autoLogin = false;
      } else {
        _email = email.trim();
        _password = password;
      }
    }
  }

  void _schedule(void Function() fn, int ms) {
    _timers.add(Timer(Duration(milliseconds: ms), fn));
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _onMessage(String data) {
    try {
      final msg = jsonDecode(data) as Map<String, dynamic>;
      if (msg['type'] == 'TOKEN' && (msg['token'] as String? ?? '').length > 50) {
        _finishLogin(msg['token'] as String);
      } else if (msg['type'] == 'USERNAME' && (msg['name'] as String? ?? '').isNotEmpty) {
        Session.saveUserName(msg['name'] as String);
        context.read<AuthProvider>().setUserName(msg['name'] as String);
      } else if (msg['type'] == 'AUTOFILL' && _autoLogin) {
        final status = msg['status'] as String? ?? '';
        if (['no-field', 'email-no-btn', 'pwd-no-btn', 'kmsi-no-btn']
            .contains(status)) {
          _schedule(() {
            if (_autoLogin) _handleAutoFill();
          }, 1000);
        }
      }
    } catch (_) {}
  }

  void _onNavigation(String url) {
    _currentUrl = url;
    _checkTokenInUrl(url);
    if (!_loginDone) {
      setState(() => _loading = true);
    }
    if (url.startsWith(_appBase) && !_loginDone && !_tokenFound) {
      _startTokenPolling();
    }
  }

  void _onLoadEnd(String url) {
    if (!_loginDone && url.startsWith(_appBase)) {
      _checkTokenInUrl(url);
    }
    if (!_loginDone && url.startsWith(_appBase)) {
      _startTokenPolling();
    } else if (!_loginDone) {
      setState(() => _loading = false);
    }
    _handleAutoFill();
  }

  void _checkTokenInUrl(String url) {
    if (_loginDone) return;
    final token = _getQueryToken(url);
    if (token != null) {
      _finishLogin(token);
    }
  }

  void _startTokenPolling() {
    if (_loginDone || _tokenFound) return;
    _tokenAttempts += 1;
    if (_tokenAttempts > 25) {
      setState(() => _loading = false);
      showToast('Não foi possível obter o token. Use "Entrar com token".', isError: true);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }
    _webViewController.runJavaScript(_captureTokenScript);
    _schedule(() {
      if (!_loginDone && !_tokenFound) {
        _startTokenPolling();
      }
    }, 1500);
  }

  void _handleAutoFill() {
    final url = _currentUrl;
    if (!_autoLogin ||
        _loginDone ||
        _tokenFound ||
        !url.contains('login.microsoftonline.com')) {
      return;
    }
    _webViewController.runJavaScript(_buildAutoFillScript(_email, _password));
  }

  Future<void> _finishLogin(String token) async {
    if (_loginDone) return;
    _loginDone = true;
    _tokenFound = true;
    setState(() {
      _loading = true;
      _loadingText = 'Entrando...';
    });
    _webViewController.runJavaScript(_captureUsernameScript);
    await context.read<AuthProvider>().setAuthenticated(token);
    // A tela WebView foi empurrada por cima da Root; ao autenticar, a Root
    // já exibe a Home, mas este widget continuaria por cima. Fazemos pop até
    // a rota raiz para revelar a Home.
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          // Barra fina e NÃO-bloqueante durante a navegação normal.
          if (_loading && !_loginDone)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.primary,
                backgroundColor: Color(0x33E60014),
              ),
            ),
          // Overlay bloqueante só após capturar o token ("Entrando...").
          if (_loginDone)
            Container(
              color: const Color(0xE6FFFFFF),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 12),
                    Text(_loadingText,
                        style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
