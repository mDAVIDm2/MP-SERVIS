import 'dart:async';

/// Отложенная отправка локального состояния на сервер (`PUT /profile/client-app-state`).
/// Регистрация: [registerClientAppStatePush] из [Consumer] в `main.dart`.
typedef ClientAppStatePushFn = Future<void> Function();

ClientAppStatePushFn? _registeredPush;
Timer? _debounce;

void registerClientAppStatePush(ClientAppStatePushFn fn) {
  _registeredPush = fn;
}

void scheduleClientAppStatePush() {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 900), () {
    final f = _registeredPush;
    if (f != null) {
      unawaited(f());
    }
  });
}
