import '../config/app_config.dart';



/// Публичные URL медиа (фото СТО и т.п.): абсолютные оставляем; относительные склеиваем с базой API.

String? resolvePublicMediaUrl(String? stored) {

  if (stored == null) return null;

  final s = stored.trim();

  if (s.isEmpty) return null;

  if (s.startsWith('http://') || s.startsWith('https://')) return s;

  final path = s.startsWith('/') ? s : '/$s';

  var base = AppConfig.baseUrl;

  if (base.endsWith('/')) base = base.substring(0, base.length - 1);

  if (path.startsWith('/api/v1')) {

    final rest = path.length > 7 ? path.substring('/api/v1'.length) : '';

    return '$base$rest';

  }

  return '$base$path';

}



/// URL аватара для Control Center: запрос с internal JWT (`GET internal/users/:id/avatar/:file`).

String? internalAvatarImageUrl(String? avatarUrlFromApi) {

  if (avatarUrlFromApi == null || avatarUrlFromApi.isEmpty) return null;

  final m = RegExp(r'/profile/avatar/([^/]+)/([^/?#]+)').firstMatch(avatarUrlFromApi);

  if (m == null) return null;

  final userId = m.group(1)!;

  final filename = Uri.decodeComponent(m.group(2)!);

  final base = AppConfig.baseUrl;

  return '${base}internal/users/$userId/avatar/${Uri.encodeComponent(filename)}';

}



/// URL фото авто для Control Center: `GET internal/client-cars/photo-file/:carId/:file`.

String? internalClientCarPhotoImageUrl(String? profileCarPhotoUrlFromApi) {

  if (profileCarPhotoUrlFromApi == null || profileCarPhotoUrlFromApi.isEmpty) return null;

  final s = profileCarPhotoUrlFromApi.trim();

  final base = AppConfig.baseUrl;



  if (s.contains('internal/client-cars/photo-file/')) {

    if (s.startsWith('http://') || s.startsWith('https://')) return s;

    return resolvePublicMediaUrl(s);

  }



  Uri uri;

  if (s.startsWith('http://') || s.startsWith('https://')) {

    uri = Uri.parse(s);

  } else {

    final path = s.startsWith('/') ? s : '/$s';

    uri = Uri.parse('https://stub.invalid$path');

  }

  final segs = uri.pathSegments;

  for (var i = 0; i + 4 < segs.length; i++) {

    if (segs[i].toLowerCase() == 'profile' &&

        segs[i + 1].toLowerCase() == 'cars' &&

        segs[i + 3].toLowerCase() == 'photo-file') {

      final carId = segs[i + 2];

      final rest = segs.sublist(i + 4);

      if (carId.isEmpty || rest.isEmpty) return null;

      final filename = rest.join('/');

      return '${base}internal/client-cars/photo-file/$carId/${Uri.encodeComponent(Uri.decodeComponent(filename))}';

    }

  }



  final m = RegExp(r'/profile/cars/([^/]+)/photo-file/([^/?#]+)', caseSensitive: false).firstMatch(s);

  if (m == null) return null;

  final carId = m.group(1)!;

  final filename = Uri.decodeComponent(m.group(2)!);

  return '${base}internal/client-cars/photo-file/$carId/${Uri.encodeComponent(filename)}';

}

