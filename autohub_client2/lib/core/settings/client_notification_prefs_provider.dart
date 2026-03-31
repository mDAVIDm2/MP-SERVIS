import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_provider.dart';
import '../providers/app_providers.dart';

const _kSound = 'client_notif_sound_';
const _kVib = 'client_notif_vib_';

/// Настройки уведомлений: типы и master push — на сервере; звук/вибро — локально.
class ClientNotificationPrefs {
  final bool pushEnabled;
  final bool orderUpdates;
  final bool chatMessages;
  final bool promotions;
  final bool reminders;
  final bool sound;
  final bool vibration;

  const ClientNotificationPrefs({
    this.pushEnabled = true,
    this.orderUpdates = true,
    this.chatMessages = true,
    this.promotions = false,
    this.reminders = true,
    this.sound = true,
    this.vibration = true,
  });

  ClientNotificationPrefs copyWith({
    bool? pushEnabled,
    bool? orderUpdates,
    bool? chatMessages,
    bool? promotions,
    bool? reminders,
    bool? sound,
    bool? vibration,
  }) {
    return ClientNotificationPrefs(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      orderUpdates: orderUpdates ?? this.orderUpdates,
      chatMessages: chatMessages ?? this.chatMessages,
      promotions: promotions ?? this.promotions,
      reminders: reminders ?? this.reminders,
      sound: sound ?? this.sound,
      vibration: vibration ?? this.vibration,
    );
  }

  static ClientNotificationPrefs fromServerMap(Map<String, dynamic> m) {
    bool b(String k, bool def) {
      final v = m[k];
      if (v is bool) return v;
      return def;
    }

    return ClientNotificationPrefs(
      pushEnabled: b('pushEnabled', true),
      orderUpdates: b('orderUpdates', true),
      chatMessages: b('chatMessages', true),
      promotions: b('promotions', false),
      reminders: b('reminders', true),
      sound: true,
      vibration: true,
    );
  }

  Map<String, dynamic> toServerPatch() {
    return {
      'pushEnabled': pushEnabled,
      'orderUpdates': orderUpdates,
      'chatMessages': chatMessages,
      'promotions': promotions,
      'reminders': reminders,
    };
  }
}

final clientNotificationPrefsProvider =
    StateNotifierProvider<ClientNotificationPrefsNotifier, AsyncValue<ClientNotificationPrefs>>((ref) {
  return ClientNotificationPrefsNotifier(ref);
});

class ClientNotificationPrefsNotifier extends StateNotifier<AsyncValue<ClientNotificationPrefs>> {
  ClientNotificationPrefsNotifier(this._ref) : super(const AsyncValue.loading()) {
    _ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.user?.id != prev?.user?.id) {
        if (next.user == null) {
          state = const AsyncValue.data(ClientNotificationPrefs());
        } else {
          load();
        }
      }
    });
    final u = _ref.read(authProvider).user;
    if (u != null) {
      load();
    } else {
      state = const AsyncValue.data(ClientNotificationPrefs());
    }
  }

  final Ref _ref;

  Future<void> load() async {
    final user = _ref.read(authProvider).user;
    if (user == null) {
      state = const AsyncValue.data(ClientNotificationPrefs());
      return;
    }
    state = const AsyncValue.loading();
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    final api = _ref.read(notificationApiServiceProvider);
    final r = await api.getNotificationPreferences();
    final data = r.dataOrNull;
    if (data == null) {
      state = AsyncValue.data(_withLocalOnly(prefs, user.id, const ClientNotificationPrefs()));
      return;
    }
    final base = ClientNotificationPrefs.fromServerMap(data);
    state = AsyncValue.data(_withLocalOnly(prefs, user.id, base));
  }

  ClientNotificationPrefs _withLocalOnly(SharedPreferences? p, String userId, ClientNotificationPrefs base) {
    if (p == null) return base;
    return base.copyWith(
      sound: p.getBool(_kSound + userId) ?? true,
      vibration: p.getBool(_kVib + userId) ?? true,
    );
  }

  Future<void> setServerFields(ClientNotificationPrefs next) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;
    final prev = state.valueOrNull ?? const ClientNotificationPrefs();
    final merged = next.copyWith(sound: prev.sound, vibration: prev.vibration);
    state = AsyncValue.data(merged);
    final api = _ref.read(notificationApiServiceProvider);
    final r = await api.patchNotificationPreferences(merged.toServerPatch());
    if (r.dataOrNull != null) {
      state = AsyncValue.data(_withLocalOnly(
        await _ref.read(sharedPreferencesProvider.future),
        user.id,
        ClientNotificationPrefs.fromServerMap(r.dataOrNull!),
      ));
    }
    _ref.invalidate(unreadNotificationCountProvider);
    _ref.invalidate(unreadByCarProvider);
    _ref.invalidate(notificationsProvider);
  }

  Future<void> setSound(bool v) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;
    final cur = state.valueOrNull ?? const ClientNotificationPrefs();
    state = AsyncValue.data(cur.copyWith(sound: v));
    final p = await _ref.read(sharedPreferencesProvider.future);
    await p.setBool(_kSound + user.id, v);
  }

  Future<void> setVibration(bool v) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;
    final cur = state.valueOrNull ?? const ClientNotificationPrefs();
    state = AsyncValue.data(cur.copyWith(vibration: v));
    final p = await _ref.read(sharedPreferencesProvider.future);
    await p.setBool(_kVib + user.id, v);
  }

  /// Разрешён ли показ push/локального уведомления по типу с бэкенда: `chat` | `order` | `pending_car_approved` | …
  bool allowsBackendType(String? type) {
    final p = state.valueOrNull;
    if (p == null) return true;
    if (!p.pushEnabled) return false;
    final t = type ?? '';
    if (t == 'chat') return p.chatMessages;
    if (t == 'order') return p.orderUpdates;
    if (t == 'general') return p.promotions;
    if (t.startsWith('pending_car')) return p.reminders;
    return true;
  }
}
