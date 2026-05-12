import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/utils/russian_mobile_phone.dart';
import '../../../../shared/models/car_model.dart';

/// Нижний лист: запрос передачи авто другому клиенту по номеру телефона.
Future<void> showCarTransferSheet(BuildContext context, WidgetRef ref, Car car) async {
  final phoneCtrl = TextEditingController(text: RussianMobilePhone.prefix);
  var shareOrders = true;
  var shareChats = true;
  var shareNotes = true;
  var shareMaintenance = true;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).extension<ClientPalette>()?.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSt) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Передача «${car.displayName}»',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ctx.palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Укажите номер телефона нового владельца в MP-Servis. Он получит запрос в приложении и сможет принять или отклонить передачу.',
                  style: TextStyle(fontSize: 14, color: ctx.palette.textSecondary, height: 1.35),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [RussianMobilePhoneInputFormatter()],
                  style: TextStyle(color: ctx.palette.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Телефон получателя',
                    labelStyle: TextStyle(color: ctx.palette.textSecondary),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: ctx.palette.border)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: ctx.palette.primary)),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Передать историю заказов по этому авто',
                    style: TextStyle(fontSize: 14, color: ctx.palette.textPrimary),
                  ),
                  subtitle: Text(
                    'Новый владелец увидит в приложении записи в СТО, сделанные с этой машиной.',
                    style: TextStyle(fontSize: 12, color: ctx.palette.textSecondary),
                  ),
                  value: shareOrders,
                  onChanged: (v) => setSt(() => shareOrders = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Передать переписки по этому авто',
                    style: TextStyle(fontSize: 14, color: ctx.palette.textPrimary),
                  ),
                  subtitle: Text(
                    'Чаты с СТО, привязанные к заказам с этой машиной, откроются на номере получателя.',
                    style: TextStyle(fontSize: 12, color: ctx.palette.textSecondary),
                  ),
                  value: shareChats,
                  onChanged: (v) => setSt(() => shareChats = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Передать заметки к этому авто',
                    style: TextStyle(fontSize: 14, color: ctx.palette.textPrimary),
                  ),
                  subtitle: Text(
                    'Личные заметки из профиля, привязанные к машине, скопируются получателю.',
                    style: TextStyle(fontSize: 12, color: ctx.palette.textSecondary),
                  ),
                  value: shareNotes,
                  onChanged: (v) => setSt(() => shareNotes = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Передать напоминания ТО и историю замен',
                    style: TextStyle(fontSize: 14, color: ctx.palette.textPrimary),
                  ),
                  subtitle: Text(
                    'Интервалы, записи вручную и учёт синхронизации с заказами по этой машине — в аккаунт получателя.',
                    style: TextStyle(fontSize: 12, color: ctx.palette.textSecondary),
                  ),
                  value: shareMaintenance,
                  onChanged: (v) => setSt(() => shareMaintenance = v),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final e164 = RussianMobilePhone.e164OrNull(phoneCtrl.text);
                    if (e164 == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Введите полный номер телефона')),
                      );
                      return;
                    }
                    final ok = await ref.read(carsProvider.notifier).createCarTransfer(
                      car.id,
                      e164,
                      options: {
                        'share_order_history': shareOrders,
                        'share_chat_history': shareChats,
                        'share_notes': shareNotes,
                        'share_maintenance': shareMaintenance,
                      },
                    );
                    if (!ctx.mounted) return;
                    if (ok) {
                      ref.invalidate(outgoingCarTransfersProvider);
                      ref.invalidate(incomingCarTransfersProvider);
                      Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Запрос на передачу отправлен')),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Не удалось отправить запрос')),
                      );
                    }
                  },
                  child: const Text('Отправить запрос'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
              ],
            );
          },
        ),
      );
    },
  );
  phoneCtrl.dispose();
}
