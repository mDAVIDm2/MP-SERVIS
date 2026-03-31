import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/repositories/client_notes_repository.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/widgets/mobile_order_card.dart';

class ClientDetailScreen extends ConsumerStatefulWidget {
  final String clientName;
  final String? clientPhone;
  final List<Order> orders;

  const ClientDetailScreen({
    super.key,
    required this.clientName,
    this.clientPhone,
    required this.orders,
  });

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

  static InputDecoration _fieldDecoration(String hint) => InputDecoration(
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

  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(clientNotesRepositoryProvider);
    if (!_notesInitialized) {
      _notesInitialized = true;
      _notesController.text = notesState[_clientKey] ?? '';
    }

    final canSeePrices = ref.watch(authProvider).user?.role.canSeePrices ?? true;
    final sections = groupOrdersByCalendarDay(widget.orders, historyMode: true);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.clientName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
                color: AppColors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: AppColors.nestedBg,
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
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.phone_rounded, color: AppColors.primary.withValues(alpha: 0.95), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SelectableText(
                          widget.clientPhone!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary.withValues(alpha: 0.8)),
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
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: _fieldDecoration('Заметки по клиенту (только для сотрудников)'),
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
              color: AppColors.textSecondary,
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
                  style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.95)),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            for (var s = 0; s < sections.length; s++) ...[
              MobileDayHeader(day: sections[s].key, isFirst: s == 0),
              ...sections[s].value.map(
                (o) => MobileOrderCard(order: o, canSeePrices: canSeePrices),
              ),
            ],
        ],
      ),
    );
  }
}
