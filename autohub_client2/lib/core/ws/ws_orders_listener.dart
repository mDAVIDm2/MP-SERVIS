import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/api_endpoints.dart';
import '../auth/auth_provider.dart';
import '../config/app_config.dart';
import '../providers/app_providers.dart';

/// Слушает WebSocket и при событии order.status_changed инвалидирует список заказов.
class WsOrdersListener extends ConsumerStatefulWidget {
  final Widget child;

  const WsOrdersListener({super.key, required this.child});

  @override
  ConsumerState<WsOrdersListener> createState() => _WsOrdersListenerState();
}

class _WsOrdersListenerState extends ConsumerState<WsOrdersListener> {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _closed = false;
  Timer? _reconnectTimer;

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_closed && mounted) {
        _connect(ref.read(authProvider).accessToken);
      }
      _reconnectTimer = null;
    });
  }

  void _connect(String? accessToken) {
    if (_closed || accessToken == null || accessToken.isEmpty) return;
    if (!AppConfig.enableWs) return;
    try {
      var wsUrl = ApiEndpoints.wsUrl;
      if (wsUrl.contains('#')) wsUrl = wsUrl.substring(0, wsUrl.indexOf('#'));
      if (wsUrl.startsWith('http://')) wsUrl = 'ws://${wsUrl.substring(7)}';
      if (wsUrl.startsWith('https://')) wsUrl = 'wss://${wsUrl.substring(8)}';
      final uri = Uri.parse(wsUrl).replace(
        queryParameters: {'token': accessToken},
      );
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.handleError((Object e, StackTrace st) {
        if (kDebugMode) debugPrint('[WsOrdersListener] stream error (ignored): $e');
        if (mounted && !_closed) {
          _channel = null;
          _sub?.cancel();
          _sub = null;
          _scheduleReconnect();
        }
      }).listen(
        _onData,
        onError: (Object e) {
          if (kDebugMode) debugPrint('[WsOrdersListener] onError (ignored): $e');
          _channel = null;
          _sub?.cancel();
          _sub = null;
          _scheduleReconnect();
        },
        onDone: () {
          if (kDebugMode) debugPrint('[WsOrdersListener] onDone');
          _channel = null;
          _sub?.cancel();
          _sub = null;
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('[WsOrdersListener] connect error (ignored): $e');
      _channel = null;
      _sub = null;
      _scheduleReconnect();
    }
  }

  void _onData(dynamic data) {
    try {
      final map = jsonDecode(data as String) as Map<String, dynamic>;
      final type = map['type'] as String? ?? map['event'] as String? ?? '';
      if (type == 'order.status_changed') {
        ref.invalidate(ordersProvider);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _closed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(authProvider).accessToken;
    ref.listen<AuthState>(authProvider, (prev, next) {
      final newToken = next.accessToken;
      if (prev?.accessToken != newToken) {
        _sub?.cancel();
        _channel?.sink.close();
        _channel = null;
        _sub = null;
        if (newToken != null && newToken.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _connect(newToken));
        }
      }
    });
    if (token != null && token.isNotEmpty && _channel == null && !_closed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _channel == null && !_closed) _connect(token);
      });
    }
    return widget.child;
  }
}
