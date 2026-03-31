import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../shared/models/settings_models.dart';

class MessageTemplateEditScreen extends ConsumerStatefulWidget {
  final MessageTemplate? template;

  const MessageTemplateEditScreen({super.key, this.template});

  @override
  ConsumerState<MessageTemplateEditScreen> createState() => _MessageTemplateEditScreenState();
}

class _MessageTemplateEditScreenState extends ConsumerState<MessageTemplateEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.template?.title ?? '');
    _bodyController = TextEditingController(text: widget.template?.body ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.template == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isNew ? 'Новый шаблон' : 'Редактировать шаблон'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Название шаблона',
              hintText: 'Подтверждение записи',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bodyController,
            decoration: const InputDecoration(
              labelText: 'Текст сообщения',
              hintText: 'Ваша запись подтверждена...',
              alignLabelWithHint: true,
            ),
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  void _save() {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) return;

    final repo = ref.read(settingsRepositoryProvider.notifier);
    if (widget.template != null) {
      repo.updateTemplate(widget.template!.copyWith(title: title, body: body));
    } else {
      final id = 't_${DateTime.now().millisecondsSinceEpoch}';
      repo.addTemplate(MessageTemplate(id: id, title: title, body: body));
    }
    Navigator.pop(context);
  }
}
