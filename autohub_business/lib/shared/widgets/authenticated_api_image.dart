import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/services/api_services_providers.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/api_path_for_dio.dart';
import '../../core/utils/api_uri_authority.dart';

/// Превью по URL: для своего API — Dio + JWT (как в клиентском приложении); иначе [Image.network].
class AuthenticatedApiImage extends ConsumerStatefulWidget {
  const AuthenticatedApiImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.directions_car_outlined,
  });

  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final IconData placeholderIcon;

  @override
  ConsumerState<AuthenticatedApiImage> createState() => _AuthenticatedApiImageState();
}

class _AuthenticatedApiImageState extends ConsumerState<AuthenticatedApiImage> {
  Uint8List? _bytes;
  bool _loading = false;
  String? _lastResolved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedApiImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _bytes = null;
      _lastResolved = null;
      _load();
    }
  }

  Future<void> _load() async {
    final raw = widget.imageUrl?.trim() ?? '';
    if (raw.isEmpty) return;
    final normalized = AppConfig.resolveCarOrOrderPhotoUrl(raw);
    final resolved = AppConfig.resolveApiMediaUrl(normalized);
    if (resolved == null || resolved.isEmpty) return;

    final base = apiBusinessBaseUri();
    final uri = Uri.tryParse(resolved);
    final same = uri != null && (uri.isScheme('http') || uri.isScheme('https')) && apiUriSameAuthority(uri, base);
    if (!same) return;

    var pathForDio = apiPathForDioBytes(resolved);
    final abs = Uri.tryParse(pathForDio);
    final useBytes = (!pathForDio.startsWith('http://') && !pathForDio.startsWith('https://')) ||
        (abs != null && apiUriSameAuthority(abs, base));
    if (!useBytes) return;

    if (!mounted) return;
    setState(() => _loading = true);
    final r = await ref.read(apiClientProvider).getBytes(pathForDio);
    if (!mounted) return;
    r.when(
      success: (list) {
        setState(() {
          _bytes = Uint8List.fromList(list);
          _loading = false;
          _lastResolved = resolved;
        });
      },
      failure: (_) => setState(() {
        _bytes = null;
        _loading = false;
        _lastResolved = resolved;
      }),
    );
  }

  Widget _placeholder() => Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black12,
        alignment: Alignment.center,
        child: Icon(widget.placeholderIcon, size: widget.width * 0.42, color: Colors.black26),
      );

  @override
  Widget build(BuildContext context) {
    final raw = widget.imageUrl?.trim() ?? '';
    final normalized = AppConfig.resolveCarOrOrderPhotoUrl(raw);
    final resolved = AppConfig.resolveApiMediaUrl(normalized);
    final r = BorderRadius.circular(widget.borderRadius);

    if (resolved == null || resolved.isEmpty) {
      return ClipRRect(borderRadius: r, child: _placeholder());
    }

    final base = apiBusinessBaseUri();
    final uri = Uri.tryParse(resolved);
    final same = uri != null && (uri.isScheme('http') || uri.isScheme('https')) && apiUriSameAuthority(uri, base);
    if (same) {
      final pathForDio = apiPathForDioBytes(resolved);
      final relUri = Uri.tryParse(pathForDio);
      final useBytes = (!pathForDio.startsWith('http://') && !pathForDio.startsWith('https://')) ||
          (relUri != null && apiUriSameAuthority(relUri, base));
      if (useBytes) {
        if (_bytes != null && _lastResolved == resolved) {
          return ClipRRect(
            borderRadius: r,
            child: Image.memory(
              _bytes!,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => _placeholder(),
            ),
          );
        }
        if (_loading || _lastResolved != resolved) {
          return ClipRRect(
            borderRadius: r,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }
        return ClipRRect(borderRadius: r, child: _placeholder());
      }
    }

    final token = ref.watch(authProvider).accessToken;
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return ClipRRect(
      borderRadius: r,
      child: Image.network(
        resolved,
        key: ValueKey<String>(resolved),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        headers: headers.isEmpty ? null : headers,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: widget.width,
            height: widget.height,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      ),
    );
  }
}
