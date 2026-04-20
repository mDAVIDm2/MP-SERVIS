import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kDeviceId = 'mp_servis_device_install_id';

/// Стабильный id устройства для сессий на бэкенде.
Future<String> getOrCreateDeviceId(SharedPreferences prefs) async {
  var id = prefs.getString(_kDeviceId);
  if (id != null && id.isNotEmpty) return id;
  id = const Uuid().v4();
  await prefs.setString(_kDeviceId, id);
  return id;
}
