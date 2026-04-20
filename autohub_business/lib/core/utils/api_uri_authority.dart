import '../api/api_endpoints.dart';

int _defaultPortForScheme(String scheme) {
  switch (scheme) {
    case 'https':
      return 443;
    case 'http':
      return 80;
    default:
      return 0;
  }
}

/// Тот же API-хост, что и [ApiEndpoints.baseUrl], без ложного расхождения `host` и `host:443`.
bool apiUriSameAuthority(Uri? u, Uri base) {
  if (u == null) return false;
  if (!(u.isScheme('http') || u.isScheme('https'))) return false;
  if (u.scheme != base.scheme) return false;
  if (u.host.toLowerCase() != base.host.toLowerCase()) return false;
  final up = u.hasPort ? u.port : _defaultPortForScheme(u.scheme);
  final bp = base.hasPort ? base.port : _defaultPortForScheme(base.scheme);
  return up == bp;
}

Uri apiBusinessBaseUri() {
  final apiBase = ApiEndpoints.baseUrl.trim();
  final s = apiBase.endsWith('/') ? apiBase.substring(0, apiBase.length - 1) : apiBase;
  return Uri.parse(s);
}
