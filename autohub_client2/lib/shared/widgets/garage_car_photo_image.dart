import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/utils/api_path_for_dio.dart';
import '../../core/utils/api_uri_authority.dart';

/// Превью фото автомобиля: локальный файл, публичный URL или ресурс API с заголовком Authorization.
class GarageCarPhotoImage extends ConsumerStatefulWidget {
  const GarageCarPhotoImage({
    super.key,
    required this.photoUrl,
    this.fit = BoxFit.cover,
  });

  final String? photoUrl;
  final BoxFit fit;

  @override
  ConsumerState<GarageCarPhotoImage> createState() => _GarageCarPhotoImageState();
}

class _GarageCarPhotoImageState extends ConsumerState<GarageCarPhotoImage> {
  Uint8List? _bytes;
  bool _loading = false;
  String? _lastUrl;

  @override
  void didUpdateWidget(GarageCarPhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _bytes = null;
      _lastUrl = null;
      _load();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = widget.photoUrl?.trim();
    if (raw == null || raw.isEmpty) return;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      final uri = Uri.tryParse(raw);
      final base = apiClientBaseUri();
      final sameOrigin = apiUriSameAuthority(uri, base);
      if (sameOrigin) {
        final pathForDio = apiPathForDioBytes(raw);
        final abs = Uri.tryParse(pathForDio);
        final useAuthBytes = (!pathForDio.startsWith('http://') && !pathForDio.startsWith('https://')) ||
            (abs != null && apiUriSameAuthority(abs, base));
        if (useAuthBytes) {
          setState(() => _loading = true);
          final r = await ref.read(apiClientProvider).getBytes(pathForDio);
          if (!mounted) return;
          r.when(
            success: (list) {
              setState(() {
                _bytes = Uint8List.fromList(list);
                _loading = false;
                _lastUrl = raw;
              });
            },
            failure: (_) => setState(() {
              _bytes = null;
              _loading = false;
              _lastUrl = raw;
            }),
          );
          return;
        }
      }
      setState(() {
        _bytes = null;
        _lastUrl = raw;
        _loading = false;
      });
      return;
    }
    if (raw.startsWith('/')) {
      setState(() => _loading = true);
      final pathForDio = apiPathForDioBytes(raw);
      final r = await ref.read(apiClientProvider).getBytes(pathForDio);
      if (!mounted) return;
      r.when(
        success: (list) {
          setState(() {
            _bytes = Uint8List.fromList(list);
            _loading = false;
            _lastUrl = raw;
          });
        },
        failure: (_) => setState(() {
          _bytes = null;
          _loading = false;
          _lastUrl = raw;
        }),
      );
      return;
    }
    final f = File(raw);
    if (await f.exists()) {
      final b = await f.readAsBytes();
      if (!mounted) return;
      setState(() {
        _bytes = b;
        _lastUrl = raw;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.photoUrl?.trim();
    if (raw == null || raw.isEmpty) {
      return _placeholder(context);
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      final uri = Uri.tryParse(raw);
      final base = apiClientBaseUri();
      final sameOrigin = apiUriSameAuthority(uri, base);
      if (sameOrigin) {
        final rel = apiPathForDioBytes(raw);
        final relUri = Uri.tryParse(rel);
        final useAuth = (!rel.startsWith('http://') && !rel.startsWith('https://')) ||
            (relUri != null && apiUriSameAuthority(relUri, base));
        if (useAuth) {
          if (_bytes != null && _lastUrl == raw) {
            return Image.memory(
              _bytes!,
              fit: widget.fit,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => _placeholder(context),
            );
          }
          if (_loading || _lastUrl != raw) {
            return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
          }
          // Ошибка getBytes — не CachedNetworkImage (нужен Bearer).
          return _placeholder(context);
        }
      }
      return CachedNetworkImage(
        imageUrl: raw,
        fit: widget.fit,
        placeholder: (_, _) => _placeholder(context),
        errorWidget: (context, url, error) => _placeholder(context),
      );
    }
    if (raw.startsWith('/')) {
      if (_loading && _bytes == null) {
        return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
      }
      if (_bytes != null) {
        return Image.memory(
          _bytes!,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _placeholder(context),
        );
      }
      return _placeholder(context);
    }
    final f = File(raw);
    if (_bytes != null && _lastUrl == raw) {
      return Image.memory(
        _bytes!,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _placeholder(context),
      );
    }
    if (f.existsSync()) {
      return Image.file(f, fit: widget.fit);
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: Colors.white.withValues(alpha: 0.06),
      child: Center(
        child: Icon(Icons.directions_car_outlined, size: 40, color: Colors.white.withValues(alpha: 0.35)),
      ),
    );
  }
}
