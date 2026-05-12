import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/partner/partner_app_config.dart';
import '../../../../core/theme/client_palette.dart';

/// Просмотр витрины Pampadu (тот же URL, что `src` у iframe на сайте) в [WebView].
class OsagoPampaduScreen extends StatefulWidget {
  const OsagoPampaduScreen({super.key});

  @override
  State<OsagoPampaduScreen> createState() => _OsagoPampaduScreenState();
}

class _OsagoPampaduScreenState extends State<OsagoPampaduScreen> {
  static bool get _useEmbeddedWebView {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => true,
      _ => false,
    };
  }

  WebViewController? _controller;
  String? _configError;
  Uri? _loadUri;
  int _progress = 0;
  bool _isLoading = true;
  String? _frameErrorDescription;
  bool _bgToPaletteApplied = false;

  @override
  void initState() {
    super.initState();
    if (!PartnerAppConfig.hasPampaduOsagoUrl) {
      _configError = 'В сборке не задан адрес витрины ОСАГО. Укажите PAMPADU_OSAGO_WIDGET_URL (или значение в partner_osago_define.json).';
      return;
    }
    final raw = PartnerAppConfig.pampaduOsagoWidgetUrlTrimmed;
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      _configError = 'Некорректный URL витрины. Ожидается https-ссылка, например на b2c.pampadu.ru';
      return;
    }
    _loadUri = uri;
    if (_useEmbeddedWebView) {
      _initWebView(uri);
    } else {
      _isLoading = false;
    }
  }

  void _initWebView(Uri uri) {
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (!mounted) return;
            setState(() {
              _progress = p;
              if (p < 100) _isLoading = true;
            });
          },
          onPageStarted: (String url) {
            if (!mounted) return;
            setState(() {
              _frameErrorDescription = null;
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError e) {
            if (e.isForMainFrame != true) return;
            if (!mounted) return;
            setState(() {
              _frameErrorDescription = e.description;
              _isLoading = false;
            });
          },
        ),
      )
      ..setBackgroundColor(const Color(0x00000000));
    c.loadRequest(uri);
    _controller = c;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = _controller;
    if (c == null || _bgToPaletteApplied) return;
    _bgToPaletteApplied = true;
    unawaited(
      c.setBackgroundColor(Theme.of(context).scaffoldBackgroundColor),
    );
  }

  Future<void> _handleBack() async {
    final c = _controller;
    if (c != null) {
      try {
        if (await c.canGoBack()) {
          await c.goBack();
          return;
        }
      } catch (_) {
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _onExternalBrowser() async {
    final uri = _loadUri;
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Не удалось открыть браузер. Попробуйте скопировать ссылку в меню.'),
          backgroundColor: context.palette.error,
        ),
      );
    }
  }

  Future<void> _copyUrl() async {
    final t = _loadUri?.toString() ?? '';
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Ссылка скопирована'),
        backgroundColor: context.palette.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _refresh() async {
    final c = _controller;
    if (c == null) {
      if (_loadUri != null) await _onExternalBrowser();
      return;
    }
    setState(() {
      _frameErrorDescription = null;
      _isLoading = true;
    });
    unawaited(c.reload());
  }

  Future<void> _retryAfterError() async {
    if (_loadUri == null) return;
    if (_useEmbeddedWebView) {
      _bgToPaletteApplied = false;
      setState(() {
        _frameErrorDescription = null;
        _isLoading = true;
      });
      if (_controller != null) {
        unawaited(_controller!.loadRequest(_loadUri!));
      } else {
        _initWebView(_loadUri!);
      }
    } else {
      await _onExternalBrowser();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (_configError != null) {
      return _ConfigErrorScaffold(
        error: _configError!,
        onClose: () => Navigator.of(context).pop(),
        palette: p,
      );
    }

    if (!_useEmbeddedWebView) {
      return _ExternalOpenScaffold(
        palette: p,
        uri: _loadUri!,
        onBack: _handleBack,
        onOpen: _onExternalBrowser,
        onCopy: _copyUrl,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: _OsagoScaffold(
        palette: p,
        title: 'ОСАГО',
        isLoading: _isLoading,
        progress: _progress,
        onBack: _handleBack,
        onRefresh: _refresh,
        onOpenExternal: _onExternalBrowser,
        onCopyUrl: _copyUrl,
        body: _controller == null
            ? Center(child: CircularProgressIndicator(color: p.primary, strokeWidth: 2.5))
            : Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: p.background,
                    child: WebViewWidget(controller: _controller!),
                  ),
                  if (_frameErrorDescription != null)
                    _ErrorOverlay(
                      description: _frameErrorDescription!,
                      palette: p,
                      onRetry: _retryAfterError,
                    ),
                ],
              ),
      ),
    );
  }
}

class _OsagoScaffold extends StatelessWidget {
  const _OsagoScaffold({
    required this.palette,
    required this.title,
    required this.isLoading,
    required this.progress,
    required this.onBack,
    required this.onRefresh,
    required this.onOpenExternal,
    required this.onCopyUrl,
    required this.body,
  });

  final ClientPalette palette;
  final String title;
  final bool isLoading;
  final int progress;
  final Future<void> Function() onBack;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onOpenExternal;
  final Future<void> Function() onCopyUrl;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: TextStyle(
            color: p.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        leading: IconButton(
          onPressed: () => onBack(),
          icon: Icon(Icons.arrow_back_rounded, color: p.textPrimary, size: 24),
          tooltip: 'Назад',
        ),
        actions: [
          IconButton(
            onPressed: () => onRefresh(),
            icon: Icon(
              Icons.refresh_rounded,
              color: p.primary,
            ),
            tooltip: 'Обновить',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: p.textSecondary),
            onSelected: (v) {
              if (v == 'ext') onOpenExternal();
              if (v == 'copy') onCopyUrl();
            },
            itemBuilder: (c) => [
              PopupMenuItem(
                value: 'ext',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.open_in_new_rounded, size: 22, color: p.textPrimary),
                  title: const Text('В браузере', style: TextStyle(fontSize: 15)),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'copy',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.link_rounded, size: 22, color: p.textPrimary),
                  title: const Text('Скопировать ссылку', style: TextStyle(fontSize: 15)),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
        bottom: isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2.5),
                child: LinearProgressIndicator(
                  value: (progress > 0 && progress < 100) ? progress / 100.0 : null,
                  minHeight: 2.5,
                  backgroundColor: p.border.withValues(alpha: 0.25),
                  color: p.primary,
                ),
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: body,
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({
    required this.description,
    required this.palette,
    required this.onRetry,
  });

  final String description;
  final ClientPalette palette;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return ColoredBox(
      color: p.background.withValues(alpha: 0.95),
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.border.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: p.shadowDark.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_tethering_error_rounded, size: 48, color: p.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      'Не удалось загрузить страницу',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.textSecondary, fontSize: 14, height: 1.35),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () => onRetry(),
                      style: FilledButton.styleFrom(
                        backgroundColor: p.primary,
                        foregroundColor: p.onAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('Повторить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfigErrorScaffold extends StatelessWidget {
  const _ConfigErrorScaffold({
    required this.error,
    required this.onClose,
    required this.palette,
  });

  final String error;
  final VoidCallback onClose;
  final ClientPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        leading: IconButton(
          onPressed: onClose,
          icon: Icon(Icons.close_rounded, color: p.textPrimary),
        ),
        title: Text('ОСАГО', style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600)),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings_outlined, size: 48, color: p.textMuted),
              const SizedBox(height: 16),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textSecondary, fontSize: 15, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExternalOpenScaffold extends StatelessWidget {
  const _ExternalOpenScaffold({
    required this.palette,
    required this.uri,
    required this.onBack,
    required this.onOpen,
    required this.onCopy,
  });

  final ClientPalette palette;
  final Uri uri;
  final Future<void> Function() onBack;
  final Future<void> Function() onOpen;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) unawaited(onBack());
      },
      child: Scaffold(
        backgroundColor: p.background,
        appBar: AppBar(
          backgroundColor: p.background,
          leading: IconButton(
            onPressed: () => onBack(),
            icon: Icon(Icons.arrow_back_rounded, color: p.textPrimary),
            tooltip: 'Назад',
          ),
          title: Text('ОСАГО', style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600)),
          centerTitle: true,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: p.cardBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: p.primary.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(color: p.border.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.shield_outlined, size: 42, color: p.primary),
                ),
                const SizedBox(height: 24),
                Text(
                  'ОСАГО',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Встроенный виджет доступен в приложениях на Android и iOS. '
                  'Здесь оформление откроется в отдельном окне браузера. Сервис предоставляется партнёром.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.textSecondary,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.primary,
                    foregroundColor: p.onAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 20),
                  label: const Text('Перейти к оформлению', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onCopy,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.textPrimary,
                    side: BorderSide(color: p.border),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.link_rounded, size: 20),
                  label: const Text('Скопировать ссылку'),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  uri.toString(),
                  style: TextStyle(color: p.textMuted, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
