import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/repositories/settings_repository.dart';
import 'message_template_edit_screen.dart';
import 'message_templates_desktop_screen.dart';

class MessageTemplatesScreen extends ConsumerWidget {
  const MessageTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isDesktopPlatform) {
      return const MessageTemplatesDesktopScreen();
    }
    final templates = ref.watch(settingsRepositoryProvider).messageTemplates;
    final repo = ref.read(settingsRepositoryProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Шаблоны сообщений'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: templates.length,
        itemBuilder: (context, i) {
          final t = templates[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(t.title),
              subtitle: Text(
                t.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MessageTemplateEditScreen(template: t),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Удалить шаблон?'),
                          content: Text('«${t.title}» будет удалён.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                              onPressed: () {
                                repo.deleteTemplate(t.id);
                                if (context.mounted) Navigator.pop(ctx);
                              },
                              child: const Text('Удалить'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MessageTemplateEditScreen(),
          ),
        ),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
