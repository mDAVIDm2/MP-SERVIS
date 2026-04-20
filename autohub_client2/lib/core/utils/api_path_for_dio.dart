import '../api/api_endpoints.dart';
import 'api_uri_authority.dart';

/// Путь для [ApiClient.getBytes] относительно [ApiEndpoints.baseUrl] (заканчивается на `/api/v1`).
///
/// В Dio, если передать путь с ведущим `/`, он резолвится от **корня хоста**, а не от baseUrl —
/// получается `https://host/profile/...` вместо `https://host/api/v1/profile/...` → 404 и «фото не грузится».
String apiPathForDioBytes(String urlOrPath) {
  final apiBase = ApiEndpoints.baseUrl.trim();
  final baseUri = Uri.parse(apiBase.endsWith('/') ? apiBase.substring(0, apiBase.length - 1) : apiBase);
  final basePath = baseUri.path.replaceAll(RegExp(r'/+$'), '');
  var t = urlOrPath.trim();
  if (t.isEmpty) return t;

  String stripLeadingSlash(String p) {
    if (p.startsWith('/')) return p.substring(1);
    return p;
  }

  /// Оставить хвост относительно `/api/v1` или [basePath] без ведущего `/`.
  String relativeFromAbsolutePath(String absolutePath, {String? query}) {
    var p = absolutePath;
    const marker = '/api/v1';
    final idx = p.indexOf(marker);
    if (idx >= 0) {
      var rest = p.substring(idx + marker.length);
      rest = stripLeadingSlash(rest);
      return query != null && query.isNotEmpty ? '$rest?$query' : rest;
    }
    if (basePath.isNotEmpty && p.startsWith(basePath)) {
      var rest = p.substring(basePath.length);
      rest = stripLeadingSlash(rest);
      return query != null && query.isNotEmpty ? '$rest?$query' : rest;
    }
    return stripLeadingSlash(p);
  }

  final uri = Uri.tryParse(t);
  if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
    if (!apiUriSameAuthority(uri, baseUri)) {
      // Чужой хост — вызывающий код должен использовать другой способ загрузки.
      return t;
    }
    final q = uri.hasQuery ? uri.query : null;
    return relativeFromAbsolutePath(uri.path, query: q);
  }

  if (t.startsWith('/api/v1/')) {
    t = t.substring('/api/v1/'.length);
  } else {
    t = stripLeadingSlash(t);
  }
  return t;
}
