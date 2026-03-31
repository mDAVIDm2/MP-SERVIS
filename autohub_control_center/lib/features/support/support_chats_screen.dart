import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/internal_data_providers.dart';
import '../../core/constants/labels_ru.dart';
import '../../core/theme/app_colors.dart';
import '../sections/section_scaffold.dart';

class SupportChatsScreen extends ConsumerStatefulWidget {
  const SupportChatsScreen({super.key});

  @override
  ConsumerState<SupportChatsScreen> createState() => _SupportChatsScreenState();
}

class _SupportChatsScreenState extends ConsumerState<SupportChatsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(supportChatsProvider);
    return SectionScaffold(
      expandBody: true,
      title: 'Чаты поддержки',
      titleActions: [
        IconButton(
          tooltip: 'Обновить',
          onPressed: () => ref.invalidate(supportChatsProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: async.when(
        data: (items) {
          final q = _search.text.trim().toLowerCase();
          final filtered = q.isEmpty
              ? items
              : items.where((c) {
                  final bucket = [
                    '${c['client_phone']}',
                    '${c['client_name']}',
                    '${c['last_message_text']}',
                    '${c['order_number']}',
                    '${c['organization_name']}',
                  ].join(' ').toLowerCase();
                  return bucket.contains(q);
                }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surface,
                          hintText: 'Телефон, имя, текст сообщения…',
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                          suffixIcon: _search.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _search.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CountBadge(total: items.length, shown: filtered.length),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _ChatsEmpty(hasChats: items.isNotEmpty)
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 32),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _SupportChatTile(chat: filtered[i]),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ChatsError(message: '$e', onRetry: () => ref.invalidate(supportChatsProvider)),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.total, required this.shown});

  final int total;
  final int shown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$shown',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
          Text(
            shown == total ? 'чатов' : 'из $total',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SupportChatTile extends StatelessWidget {
  const _SupportChatTile({required this.chat});

  final Map<String, dynamic> chat;

  static String _formatAt(dynamic v) {
    if (v == null) return '';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();
    final local = d.toLocal();
    final now = DateTime.now();
    final t0 = DateTime(now.year, now.month, now.day);
    final t1 = DateTime(local.year, local.month, local.day);
    if (t1 == t0) return 'Сегодня · ${DateFormat.Hm().format(local)}';
    if (t1 == t0.subtract(const Duration(days: 1))) return 'Вчера · ${DateFormat.Hm().format(local)}';
    return DateFormat('dd.MM.yyyy HH:mm').format(local);
  }

  static String _phoneDisplay(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length == 11 && (d.startsWith('7') || d.startsWith('8'))) {
      final x = d.startsWith('8') ? '7${d.substring(1)}' : d;
      return '+7 ${x.substring(1, 4)} ${x.substring(4, 7)} ${x.substring(7, 9)} ${x.substring(9)}';
    }
    return raw.isEmpty ? '—' : '+$raw';
  }

  @override
  Widget build(BuildContext context) {
    final id = '${chat['id'] ?? ''}';
    final phoneRaw = '${chat['client_phone'] ?? ''}';
    final phone = _phoneDisplay(phoneRaw);
    final name = '${chat['client_name'] ?? ''}'.trim();
    final lastText = chat['last_message_text']?.toString() ?? '';
    final lastAt = _formatAt(chat['last_message_at']);
    final fromClient = chat['last_message_from_client'] == true;
    final unread = (chat['unread_count'] is num) ? (chat['unread_count'] as num).toInt() : int.tryParse('${chat['unread_count']}') ?? 0;
    final orderNum = '${chat['order_number'] ?? ''}'.trim();
    final orderStatus = LabelsRu.orderStatus(chat['order_status'] as String?);
    final orgName = '${chat['organization_name'] ?? 'Поддержка'}';

    final initial = name.isNotEmpty
        ? name[0].toUpperCase()
        : (phoneRaw.isNotEmpty ? (RegExp(r'\d').firstMatch(phoneRaw)?.group(0) ?? '?') : '?');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/app/support-chats/$id'),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surface,
                AppColors.primary.withValues(alpha: 0.04),
              ],
            ),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.75),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          constraints: const BoxConstraints(minWidth: 20),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name.isNotEmpty ? name : 'Клиент',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            lastAt,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary.withValues(alpha: 0.95),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.support_agent_rounded,
                            size: 16,
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              orgName,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (orderNum.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.receipt_long_outlined, size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(orderNum, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
                              ),
                              child: Text(
                                orderStatus,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (lastText.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                fromClient ? Icons.person_outline_rounded : Icons.headset_mic_outlined,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lastText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, height: 1.35, color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatsEmpty extends StatelessWidget {
  const _ChatsEmpty({required this.hasChats});

  final bool hasChats;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasChats ? Icons.search_off_rounded : Icons.forum_outlined,
                  size: 48,
                  color: AppColors.textSecondary.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 16),
                Text(
                  hasChats ? 'Ничего не найдено' : 'Обращений в поддержку нет',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                if (hasChats)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Попробуйте другой запрос.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatsError extends StatelessWidget {
  const _ChatsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Ошибка загрузки чатов', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              SelectableText(message, style: const TextStyle(color: AppColors.danger, height: 1.4)),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
