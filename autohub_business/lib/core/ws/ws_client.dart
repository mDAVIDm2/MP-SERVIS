import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../api/api_endpoints.dart';
import '../config/app_config.dart';

/// Событие от бэкенда (тип + данные).
class WsEvent {
  final String type;
  final Map<String, dynamic> payload;

  const WsEvent({required this.type, required this.payload});
}

/// WebSocket-клиент: подключение с токеном, поток событий, переподключение.
/// Если бэкенд не поднимает WebSocket на /ws — ошибки обрабатываются тихо и переподключение с бэк-оффом.
class WsClient {
  WsClient({this.accessToken});

  String? accessToken;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _eventController = StreamController<WsEvent>.broadcast();
  bool _closed = false;
  int _reconnectAttempt = 0;
  static const _maxBackoffSeconds = 30;

  Stream<WsEvent> get events => _eventController.stream;

  void connect() {
    if (_closed) return;
    if (!AppConfig.enableWs) return;
    final token = accessToken;
    String wsUrl = ApiEndpoints.wsUrl;
    if (wsUrl.contains('#')) wsUrl = wsUrl.substring(0, wsUrl.indexOf('#'));
    if (wsUrl.startsWith('http://')) wsUrl = 'ws://${wsUrl.substring(7)}';
    if (wsUrl.startsWith('https://')) wsUrl = 'wss://${wsUrl.substring(8)}';
    final uri = Uri.parse(wsUrl).replace(
      queryParameters: token != null ? {'token': token} : null,
    );
    try {
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.handleError((Object e, StackTrace st) {
        if (kDebugMode) debugPrint('[WsClient] stream error (ignored): $e');
        _onError(e);
      }).listen(
        _onData,
        onError: (Object e, StackTrace st) {
          if (kDebugMode) debugPrint('[WsClient] onError (ignored): $e');
          _onError(e);
        },
        onDone: () {
          if (kDebugMode) debugPrint('[WsClient] onDone');
          _onDone();
        },
        cancelOnError: false,
      );
      _reconnectAttempt = 0;
    } catch (e, st) {
      if (kDebugMode) debugPrint('[WsClient] connect error (ignored): $e');
      _channel = null;
      _sub = null;
      _scheduleReconnect();
    }
  }

  void _onData(dynamic data) {
    try {
      final map = jsonDecode(data as String) as Map<String, dynamic>;
      final type = map['type'] as String? ?? map['event'] as String? ?? '';
      final payload = map['payload'] as Map<String, dynamic>? ?? map['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
      _eventController.add(WsEvent(type: type, payload: payload));
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[WsClient] parse error: $e');
        debugPrint('[WsClient] data: $data');
        debugPrint(st.toString());
      }
    }
  }

  void _onError(Object e) {
    _channel = null;
    _sub?.cancel();
    _sub = null;
    _scheduleReconnect();
    // Не пробрасываем исключение — только логируем
  }

  void _onDone() {
    _channel = null;
    _sub?.cancel();
    _sub = null;
    _scheduleReconnect();
    // Не пробрасываем исключение
  }

  void _scheduleReconnect() {
    if (_closed || accessToken == null) return;
    _reconnectAttempt++;
    final sec = (3 + (_reconnectAttempt * 2)).clamp(3, _maxBackoffSeconds);
    Future.delayed(Duration(seconds: sec), () {
      if (!_closed && accessToken != null) connect();
    });
  }

  void disconnect() {
    _closed = true;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}
