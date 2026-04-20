import '../api/api_endpoints.dart';
import 'api_uri_authority.dart';

/// Путь для [ApiClient.getBytes] относительно [ApiEndpoints.baseUrl].
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
