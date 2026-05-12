import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/garage/presentation/screens/car_detail_screen.dart';
import '../../features/profile/presentation/screens/maintenance_reminders_screen.dart';
import '../settings/garage_maintenance_onboarding_provider.dart';
import '../navigation/app_navigator_key.dart';
import '../navigation/shell_navigation_provider.dart';
import '../theme/client_palette.dart';
import 'garage_first_car_tutorial_provider.dart';

/// Глобальная нижняя панель сценария (поверх всех экранов).
class GarageFirstCarTutorialLayer extends ConsumerWidget {
  const GarageFirstCarTutorialLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(garageFirstCarTutorialProvider);
    if (!st.active || st.carId == null || st.carId!.isEmpty) {
      return const SizedBox.shrink();
    }

    final step = st.step;
    if (step == GarageFirstCarTutorialStep.inactive) {
      return const SizedBox.shrink();
    }

    final palette = context.palette;
    // Панель над нижней навигацией MainShell (~72) и индикатором «домой».
    final bottomPad = MediaQuery.paddingOf(context).bottom + 72 + 12;

    String title;
    String body;
    switch (step) {
      case GarageFirstCarTutorialStep.garageReminders:
        title = 'Напоминания и уведомления';
        body =
            'Здесь настраиваются интервалы ТО по пробегу и времени, напоминания о сроках. '
            'Нажмите «Перейти к напоминаниям», чтобы выбрать работы и задать интервалы.';
        break;
      case GarageFirstCarTutorialStep.maintenanceIntro:
        title = 'Типы работ';
        body =
            'Для каждой работы задайте интервал: только пробег, только срок или оба. '
            'Можно добавить свои напоминания кнопкой «Добавить напоминание».';
        break;
      case GarageFirstCarTutorialStep.maintenanceHistory:
        title = 'История обслуживания';
        body =
            'Зафиксируйте выполненные работы вручную — при записи через приложение данные '
            'из заказов подставятся автоматически, где это возможно.';
        break;
      case GarageFirstCarTutorialStep.documentsInfo:
        title = 'Документы';
        body =
            'В карточке автомобиля можно хранить страховку, данные о ТО и другие сведения. '
            'Ниже можно открыть карточку или перейти к избранным сервисам.';
        break;
      case GarageFirstCarTutorialStep.servicesFavorites:
        title = 'Избранное';
        body =
            'Точки из раздела «Поиск» с иконкой сердца попадают сюда — быстрый доступ и запись '
            'без поиска на карте.';
        break;
      case GarageFirstCarTutorialStep.searchMapAndFilters:
        title = 'Карта и список';
        body =
            'Переключайте «Карта» и «Список», фильтруйте по типу организации и услугам. '
            'Видны расстояние, рейтинг и ориентир по ценам.';
        break;
      case GarageFirstCarTutorialStep.bookingHint:
        title = 'Запись в сервис';
        body =
            'Откройте карточку СТО: услуги и цены, отзывы, маршрут и запись на удобное время.';
        break;
      case GarageFirstCarTutorialStep.inactive:
        return const SizedBox.shrink();
    }

    final notifier = ref.read(garageFirstCarTutorialProvider.notifier);

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPad),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: palette.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.strokeGold.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.school_rounded, color: palette.gold1, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.38,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          final cid = st.carId;
                          await notifier.skip();
                          if (cid != null && cid.isNotEmpty) {
                            await ref.read(garageMaintenanceOnboardingSeenProvider.notifier).markSeen(cid);
                          }
                        },
                        child: Text(
                          'Пропустить',
                          style: TextStyle(color: palette.textTertiary),
                        ),
                      ),
                      const Spacer(),
                      if (step == GarageFirstCarTutorialStep.documentsInfo) ...[
                        TextButton(
                          onPressed: () {
                            final id = st.carId!;
                            appRootNavigatorKey.currentState?.push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => CarDetailScreen(carId: id),
                              ),
                            );
                          },
                          child: Text(
                            'Карточка авто',
                            style: TextStyle(color: palette.primary),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      _buildPrimaryButton(
                        context,
                        ref,
                        step: step,
                        carId: st.carId!,
                        notifier: notifier,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildPrimaryButton(
    BuildContext context,
    WidgetRef ref, {
    required GarageFirstCarTutorialStep step,
    required String carId,
    required GarageFirstCarTutorialNotifier notifier,
  }) {
    final palette = context.palette;

    Future<void> goMaintenance() async {
      notifier.setStep(GarageFirstCarTutorialStep.maintenanceIntro);
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MaintenanceRemindersScreen(initialCarId: carId),
        ),
      );
    }

    Future<void> nextMaintenanceIntro() async {
      notifier.setStep(GarageFirstCarTutorialStep.maintenanceHistory);
    }

    Future<void> nextMaintenanceHistory() async {
      final nav = appRootNavigatorKey.currentState;
      if (nav != null && nav.canPop()) {
        nav.pop();
      }
      ref.read(shellTargetTabProvider.notifier).state = 0;
      notifier.setStep(GarageFirstCarTutorialStep.documentsInfo);
    }

    Future<void> nextDocuments() async {
      ref.read(shellTargetTabProvider.notifier).state = 1;
      notifier.setStep(GarageFirstCarTutorialStep.servicesFavorites);
    }

    Future<void> nextServices() async {
      ref.read(shellTargetTabProvider.notifier).state = 2;
      notifier.setStep(GarageFirstCarTutorialStep.searchMapAndFilters);
    }

    Future<void> nextSearch() async {
      notifier.setStep(GarageFirstCarTutorialStep.bookingHint);
    }

    Future<void> finish() async {
      final cid = ref.read(garageFirstCarTutorialProvider).carId;
      await notifier.completeFlow();
      if (cid != null && cid.isNotEmpty) {
        await ref.read(garageMaintenanceOnboardingSeenProvider.notifier).markSeen(cid);
      }
    }

    String label;
    VoidCallback onPressed;
    switch (step) {
      case GarageFirstCarTutorialStep.garageReminders:
        label = 'Перейти к напоминаниям';
        onPressed = () => goMaintenance();
        break;
      case GarageFirstCarTutorialStep.maintenanceIntro:
        label = 'Далее';
        onPressed = () => nextMaintenanceIntro();
        break;
      case GarageFirstCarTutorialStep.maintenanceHistory:
        label = 'Далее';
        onPressed = () => nextMaintenanceHistory();
        break;
      case GarageFirstCarTutorialStep.documentsInfo:
        label = 'Далее';
        onPressed = () => nextDocuments();
        break;
      case GarageFirstCarTutorialStep.servicesFavorites:
        label = 'Далее';
        onPressed = () => nextServices();
        break;
      case GarageFirstCarTutorialStep.searchMapAndFilters:
        label = 'Далее';
        onPressed = () => nextSearch();
        break;
      case GarageFirstCarTutorialStep.bookingHint:
        label = 'Готово';
        onPressed = () => finish();
        break;
      case GarageFirstCarTutorialStep.inactive:
        label = '';
        onPressed = () {};
        break;
    }

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: palette.gold1,
        foregroundColor: palette.onAccent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
      child: Text(label),
    );
  }
}
