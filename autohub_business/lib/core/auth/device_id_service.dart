import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

const _kDeviceId = 'mp_servis_business_install_id';

/// Стабильный id установки для привязки сессий на бэкенде.
Future<String> getOrCreateDeviceId(SharedPreferences prefs) async {
  var id = prefs.getString(_kDeviceId);
  if (id != null && id.isNotEmpty) return id;
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  id = base64UrlEncode(bytes).replaceAll('=', '');
  await prefs.setString(_kDeviceId, id);
  return id;
}
