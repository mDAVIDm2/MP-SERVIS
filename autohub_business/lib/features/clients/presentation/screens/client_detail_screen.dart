import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/repositories/client_notes_repository.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/widgets/mobile_order_card.dart';
import '../../../chats/presentation/widgets/authenticated_profile_avatar.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';
import '../../../orders/presentation/widgets/orders_desktop_components.dart';

class ClientDetailScreen extends ConsumerStatefulWidget {
  final String clientName;
  final String? clientPhone;
  /// Фото профиля клиента (из списка чатов API / передано с экрана чата).
  final String? clientAvatarUrl;
  final List<Order> orders;

  const ClientDetailScreen({
    super.key,
    required this.clientName,
    this.clientPhone,
    this.clientAvatarUrl,
    required this.orders,
    this.useDesktopLightUi = false,
  });

  /// Светлая палитра (десктопный раздел «Клиенты»).
  final bool useDesktopLightUi;

  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen> {
  late TextEditingController _notesController;
  bool _notesInitialized = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String get _clientKey => clientNoteKey(widget.clientName, widget.clientPhone);

  InputDecoration _fieldDecoration(String hint, bool d) {
    if (d) {
      return InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColorsDesktop.textPlaceholder),
        filled: true,
        fillColor: AppColorsDesktop.nestedBg.withValues(alpha: 0.65),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorsDesktop.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorsDesktop.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorsDesktop.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
    }
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textTertiary.withValues(alpha: 0.9)),
      filled: true,
      fillColor: AppColors.nestedBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.85)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.85)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.65), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(clientNotesRepositoryProvider);
    if (!_notesInitialized) {
      _notesInitialized = true;
      _notesController.text = notesState[_clientKey] ?? '';
    }

    final canSeePrices = ref.watch(authProvider).user?.role.canSeePrices ?? true;
    final sections = groupOrdersByCalendarDay(widget.orders, historyMode: true);
    final d = widget.useDesktopLightUi;

    final bg = d ? AppColorsDesktop.background : AppColors.background;
    final label = d ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
    final primary = d ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final tertiary = d ? AppColorsDesktop.textTertiary : AppColors.textTertiary;
    final nested = d ? AppColorsDesktop.nestedBg.withValues(alpha: 0.65) : AppColors.nestedBg;
    final border = d ? AppColorsDesktop.border : AppColors.border.withValues(alpha: 0.5);
    final accent = d ? AppColorsDesktop.primary : AppColors.primary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Row(
          children: [
            AuthenticatedProfileAvatar(
              imageUrl: widget.clientAvatarUrl,
              fallbackLetter: widget.clientName.isNotEmpty ? widget.clientName[0] : '?',
              size: d ? 32 : 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.clientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: d ? AppColorsDesktop.surface : null,
        foregroundColor: d ? AppColorsDesktop.textPrimary : null,
        surfaceTintColor: d ? Colors.transparent : null,
        elevation: d ? 0 : null,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (widget.clientPhone != null) ...[
            Text(
              'Телефон',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: label,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: nested,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  final uri = Uri(
                    scheme: 'tel',
                    path: widget.clientPhone!.replaceAll(RegExp(r'[^\d+]'), ''),
                  );
                  launchUrl(uri);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.phone_rounded, color: accent.withValues(alpha: 0.95), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SelectableText(
                          widget.clientPhone!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: primary,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: tertiary.withValues(alpha: 0.8)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
          ],
          Text(
            'Внутренние заметки',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: label,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 4,
            style: TextStyle(color: primary),
            decoration: _fieldDecoration('Заметки по клиенту (только для сотрудников)', d),
            onChanged: (value) {
              ref.read(clientNotesRepositoryProvider.notifier).setNote(_clientKey, value);
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Заказы в этой организации',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: label,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          if (widget.orders.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 16),
              child: Center(
                child: Text(
                  'Пока нет заказов',
                  style: TextStyle(color: label.withValues(alpha: 0.95)),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            for (var s = 0; s < sections.length; s++) ...[
              if (d)
                Padding(
                  padding: EdgeInsets.only(top: s == 0 ? 0 : 14, bottom: 8),
                  child: Text(
                    MobileDayHeader.labelForDay(sections[s].key),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColorsDesktop.textPrimary,
                      letterSpacing: 0.15,
                    ),
                  ),
                )
              else
                MobileDayHeader(day: sections[s].key, isFirst: s == 0),
              ...sections[s].value.map(
                (o) => d
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: OrderListCardCompact(
                          order: o,
                          isSelected: false,
                          canSeePrices: canSeePrices,
                          compactDensity: true,
                          onTap: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => OrderDetailScreen(orderId: o.id),
                              ),
                            );
                          },
                        ),
                      )
                    : MobileOrderCard(order: o, canSeePrices: canSeePrices),
              ),
            ],
        ],
      ),
    );
  }
}
