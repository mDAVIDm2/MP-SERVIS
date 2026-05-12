import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http_parser/http_parser.dart';

/// Content-Type для части multipart (Dio иначе шлёт application/octet-stream).
MediaType mediaTypeForChatImageFilename(String filename) {
  final n = filename.toLowerCase();
  if (n.endsWith('.png')) return MediaType('image', 'png');
  if (n.endsWith('.webp')) return MediaType('image', 'webp');
  return MediaType('image', 'jpeg');
}

/// Сжатие: до 1920 по длинной стороне, JPEG 85% (сервер сохраняет в WebP).
Future<Uint8List> prepareChatImageBytesForUpload(Uint8List bytes) async {
  if (kIsWeb) return bytes;
  try {
    final out = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1920,
      minHeight: 1920,
      quality: 85,
      format: CompressFormat.jpeg,
    );
    if (out.isNotEmpty) return Uint8List.fromList(out);
  } catch (_) {}
  return bytes;
}
