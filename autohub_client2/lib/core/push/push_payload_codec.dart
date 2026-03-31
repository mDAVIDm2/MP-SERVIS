import 'dart:convert';

/// JSON payload для [FlutterLocalNotificationsPlugin.show], чтобы по тапу восстановить FCM data.
class PushPayloadCodec {
  PushPayloadCodec._();

  static String encodeFromStringMap(Map<String, String> data) {
    final m = <String, String>{};
    for (final e in data.entries) {
      if (e.value.isEmpty) continue;
      m[e.key] = e.value;
    }
    return jsonEncode(m);
  }

  static Map<String, String>? decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        final out = <String, String>{};
        decoded.forEach((k, v) {
          final s = v?.toString() ?? '';
          if (s.isNotEmpty) out[k.toString()] = s;
        });
        return out.isEmpty ? null : out;
      }
    } catch (_) {}
    final t = payload.trim();
    if (t.length >= 8) {
      return {'notification_id': t};
    }
    return null;
  }
}
