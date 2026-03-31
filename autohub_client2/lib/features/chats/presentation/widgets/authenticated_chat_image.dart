import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_endpoints.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/utils/chat_attachment_path.dart';
import '../../../../shared/models/chat_model.dart';

/// Миниатюра вложения чата: GET с Bearer из [apiClientProvider].
class AuthenticatedChatImage extends ConsumerStatefulWidget {
  const AuthenticatedChatImage({
    super.key,
    required this.attachment,
    this.maxHeight = 160,
    this.borderRadius = 8,
  });

  final ChatAttachment attachment;
  final double maxHeight;
  final double borderRadius;

  @override
  ConsumerState<AuthenticatedChatImage> createState() => _AuthenticatedChatImageState();
}

class _AuthenticatedChatImageState extends ConsumerState<AuthenticatedChatImage> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant AuthenticatedChatImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.id != widget.attachment.id || oldWidget.attachment.url != widget.attachment.url) {
      _bytes = null;
      _failed = false;
      Future.microtask(_load);
    }
  }

  Future<void> _load() async {
    final path = chatAttachmentPathForDio(widget.attachment.url, ApiEndpoints.baseUrl);
    if (path.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    final client = ref.read(apiClientProvider);
    final r = await client.getBytes(path);
    if (!mounted) return;
    r.when(
      success: (bytes) {
        if (!mounted) return;
        setState(() {
          _bytes = Uint8List.fromList(bytes);
          _failed = false;
        });
      },
      failure: (_) {
        if (!mounted) return;
        setState(() => _failed = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: const Icon(Icons.broken_image_outlined, size: 32),
      );
    }
    if (_bytes == null) {
      return Container(
        height: widget.maxHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image.memory(
        _bytes!,
        fit: BoxFit.cover,
        height: widget.maxHeight,
        width: double.infinity,
        gaplessPlayback: true,
      ),
    );
  }
}
