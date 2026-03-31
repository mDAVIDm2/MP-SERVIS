import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import 'message_template_edit_screen.dart';

/// Десктоп: шаблоны сообщений — сетка карточек и явная кнопка «Новый шаблон».
class MessageTemplatesDesktopScreen extends ConsumerWidget {
  const MessageTemplatesDesktopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(settingsRepositoryProvider).messageTemplates;
    final repo = ref.read(settingsRepositoryProvider.notifier);

    return Scaffold(
      backgroundColor: AppColorsDesktop.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColorsDesktop.surface,
        foregroundColor: AppColorsDesktop.textPrimary,
        title: const Text('Шаблоны сообщений'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MessageTemplateEditScreen()),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Новый шаблон'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColorsDesktop.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColorsDesktop.primary,
        onRefresh: () async {
          final orgId = ref.read(authProvider).user?.organizationId;
          await ref.read(settingsRepositoryProvider.notifier).load(orgId);
        },
        child: templates.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(DesktopDesignSystem.pagePadding),
                children: [
                  const SizedBox(height: 40),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        children: [
                          Icon(Icons.message_outlined, size: 56, color: AppColorsDesktop.textPlaceholder),
                          const SizedBox(height: 16),
                          Text('Шаблонов пока нет', style: DesktopDesignSystem.sectionTitle),
                          const SizedBox(height: 8),
                          Text(
                            'Создайте короткие заготовки для типовых ответов в чате — сэкономите время мастерам.',
                            textAlign: TextAlign.center,
                            style: DesktopDesignSystem.bodySecondary.copyWith(height: 1.45),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MessageTemplateEditScreen()),
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Создать первый шаблон'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColorsDesktop.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final cols = w >= 1000 ? 3 : (w >= 640 ? 2 : 1);
                  const gap = 16.0;
                  return GridView.builder(
                    padding: const EdgeInsets.all(DesktopDesignSystem.pagePadding),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: gap,
                      crossAxisSpacing: gap,
                      mainAxisExtent: 172,
                    ),
                    itemCount: templates.length,
                    itemBuilder: (context, i) {
                      final t = templates[i];
                      return _TemplateCard(
                        title: t.title,
                        body: t.body,
                        onEdit: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MessageTemplateEditScreen(template: t)),
                        ),
                        onDelete: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppColorsDesktop.surface,
                              title: const Text('Удалить шаблон?'),
                              content: Text('«${t.title}» будет удалён.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Удалить'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) repo.deleteTemplate(t.id);
                        },
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _TemplateCard extends StatefulWidget {
  const _TemplateCard({
    required this.title,
    required this.body,
    required this.onEdit,
    required this.onDelete,
  });
  final String title;
  final String body;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: AppColorsDesktop.surface,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        elevation: 0,
        child: InkWell(
          onTap: widget.onEdit,
          borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(DesktopDesignSystem.cardPaddingLarge),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
              border: Border.all(
                color: _hover ? AppColorsDesktop.primary.withValues(alpha: 0.35) : AppColorsDesktop.border,
              ),
              boxShadow: _hover ? DesktopDesignSystem.shadowCardHover : DesktopDesignSystem.shadowCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DesktopDesignSystem.sectionTitle,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      color: AppColorsDesktop.textSecondary,
                      onPressed: widget.onEdit,
                      tooltip: 'Изменить',
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: AppColors.error,
                      onPressed: widget.onDelete,
                      tooltip: 'Удалить',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    widget.body,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: DesktopDesignSystem.bodySecondary.copyWith(height: 1.4),
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
