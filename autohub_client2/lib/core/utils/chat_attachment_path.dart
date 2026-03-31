/// Путь относительно [baseUrl] клиента (…/api/v1), из полного URL в ответе API.
String chatAttachmentPathForDio(String urlFromServer, String apiBaseUrl) {
  final u = urlFromServer.trim();
  if (u.isEmpty) return u;
  final uri = Uri.tryParse(u);
  if (uri != null && uri.hasScheme) {
    var p = uri.path;
    const marker = '/api/v1';
    final i = p.indexOf(marker);
    if (i >= 0) {
      return p.substring(i + marker.length);
    }
    if (p.startsWith('/chats/')) return p;
  }
  if (u.startsWith('/chats/')) return u;
  try {
    final base = Uri.parse(apiBaseUrl.endsWith('/') ? apiBaseUrl.substring(0, apiBaseUrl.length - 1) : apiBaseUrl);
    if (uri != null && uri.path.startsWith(base.path)) {
      return uri.path.substring(base.path.length);
    }
  } catch (_) {}
  return u;
}
