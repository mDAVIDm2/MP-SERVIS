import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/internal_data_providers.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/constants/labels_ru.dart';
import '../../core/theme/app_colors.dart';
import '../sections/section_scaffold.dart';

String _formatSupportPhone(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length == 11 && (d.startsWith('7') || d.startsWith('8'))) {
    final x = d.startsWith('8') ? '7${d.substring(1)}' : d;
    return '+7 ${x.substring(1, 4)} ${x.substring(4, 7)} ${x.substring(7, 9)} ${x.substring(9)}';
  }
  return raw.isEmpty ? '—' : '+$raw';
}

class SupportChatDetailScreen extends ConsumerStatefulWidget {
  const SupportChatDetailScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<SupportChatDetailScreen> createState() => _SupportChatDetailScreenState();
}

class _SupportChatDetailScreenState extends ConsumerState<SupportChatDetailScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _markedRead = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_markedRead) return;
    _markedRead = true;
    final api = ref.read(internalApiProvider);
    api.postSupportChatRead(widget.chatId).whenComplete(() {
      ref.invalidate(supportChatsProvider);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final api = ref.read(internalApiProvider);
    await api.postSupportChatMessage(widget.chatId, text);
    if (mounted) {
      _controller.clear();
      await api.postSupportChatRead(widget.chatId);
      ref.invalidate(supportChatMessagesProvider(widget.chatId));
      ref.invalidate(supportChatsProvider);
      _scrollToBottom();
    }
    if (mounted) setState(() => _sending = false);
  }

  Map<String, dynamic>? _metaFromList(List<Map<String, dynamic>> chats) {
    for (final c in chats) {
      if ('${c['id']}' == widget.chatId) return c;
    }
    return null;
  }

  static String _formatAt(dynamic v) {
    if (v == null) return '';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();
    return DateFormat('HH:mm · dd.MM').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(supportChatsProvider);
    final meta = chatsAsync.maybeWhen(
      data: _metaFromList,
      orElse: () => null,
    );

    ref.listen(supportChatMessagesProvider(widget.chatId), (prev, next) {
      final prevLen = prev?.valueOrNull?.length;
      final list = next.valueOrNull;
      if (list == null || list.isEmpty) return;
      if (prevLen == null || list.length > prevLen) {
        _scrollToBottom();
      }
    });

    final async = ref.watch(supportChatMessagesProvider(widget.chatId));
    return SectionScaffold(
      expandBody: true,
      title: 'Диалог поддержки',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/app/support-chats'),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            label: const Text('К списку чатов'),
            style: TextButton.styleFrom(alignment: Alignment.centerLeft, foregroundColor: AppColors.primary),
          ),
          _ChatHeaderCard(chatId: widget.chatId, meta: meta),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: async.when(
                data: (msgs) {
                  if (msgs.isEmpty) {
                    return const Center(
                      child: Text('Сообщений пока нет', style: TextStyle(color: AppColors.textSecondary)),
                    );
                  }
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                    itemCount: msgs.length,
                    itemBuilder: (context, i) {
                      final m = msgs[i];
                      final system = m['is_system'] == true;
                      final text = m['text']?.toString() ?? '';
                      final at = _formatAt(m['at']);
                      final fromOp = m['is_from_support_operator'] == true ||
                          m['message_type'] == 'support_operator_reply';
                      return _MessageBubble(
                        system: system,
                        fromSupportOperator: fromOp,
                        supportChannel: m['support_channel']?.toString(),
                        isFromClient: m['is_from_client'] == true,
                        text: text,
                        at: at,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(
                      'Ошибка: $e',
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Material(
            elevation: 0,
            borderRadius: BorderRadius.circular(16),
            color: AppColors.surface,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Ваш ответ…',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatHeaderCard extends StatelessWidget {
  const _ChatHeaderCard({required this.chatId, required this.meta});

  final String chatId;
  final Map<String, dynamic>? meta;

  static String _channelLabel(String? ch) {
    switch (ch) {
      case 'business':
        return 'Приложение для бизнеса';
      case 'client':
        return 'Клиентское приложение';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final phoneRaw = meta != null ? '${meta!['client_phone'] ?? ''}' : '';
    final phone = _formatSupportPhone(phoneRaw);
    final name = meta != null ? '${meta!['client_name'] ?? ''}'.trim() : '';
    final orderNum = meta != null ? '${meta!['order_number'] ?? ''}'.trim() : '';
    final st = meta != null ? LabelsRu.orderStatus(meta!['order_status'] as String?) : null;
    final channel = meta != null ? meta!['primary_requester_channel']?.toString() : null;
    final channelLabel = _channelLabel(channel);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Обращение в поддержку',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                if (channelLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
                    ),
                    child: Text(
                      channelLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.primary.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                SelectableText(
                  phone,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.primary.withValues(alpha: 0.95),
                  ),
                ),
                if (orderNum.isNotEmpty && st != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 15, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(orderNum, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          st,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF166534)),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                SelectableText(
                  'ID чата: $chatId',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.system,
    required this.fromSupportOperator,
    required this.supportChannel,
    required this.isFromClient,
    required this.text,
    required this.at,
  });

  final bool system;
  final bool fromSupportOperator;
  final String? supportChannel;
  final bool isFromClient;
  final String text;
  final String at;

  /// Входящее обращение (не оператор): источник клиента или бизнес-приложения — без путаницы с «Поддержкой».
  static String _incomingSourceLabel(bool isFromClient, String? channel) {
    if (channel == 'client' || (channel == null && isFromClient)) {
      return 'Клиентское приложение';
    }
    if (channel == 'business') {
      return 'Приложение для бизнеса';
    }
    return isFromClient ? 'Клиентское приложение' : 'Приложение для бизнеса';
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width * 0.72;

    if (system) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Система',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SelectableText(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(at, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    // Исходящее: оператор поддержки — справа, как «свои» сообщения в бизнес-чатах.
    if (fromSupportOperator) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxW),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Оператор поддержки',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                text,
                style: const TextStyle(fontSize: 15, height: 1.45, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                at,
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      );
    }

    // Входящее: слева, светлая карточка с рамкой (как сообщения клиента в бизнес-чате).
    final source = _incomingSourceLabel(isFromClient, supportChannel);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.mark_email_unread_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    source,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              text,
              style: const TextStyle(fontSize: 15, height: 1.45, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              at,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.75)),
            ),
          ],
        ),
      ),
    );
  }
}
