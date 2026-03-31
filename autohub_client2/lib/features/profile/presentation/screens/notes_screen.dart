import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../shared/models/profile_note_model.dart';
import '../../../../shared/widgets/common_widgets.dart';

class NotesScreen extends ConsumerStatefulWidget {
  /// ID выбранного автомобиля; заметки показываются только по нему.
  final String? selectedCarId;

  const NotesScreen({super.key, this.selectedCarId});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  List<ProfileNote> get _notes {
    final all = ref.watch(profileNotesProvider);
    return all.where((n) => n.carId == (widget.selectedCarId ?? '')).toList();
  }

  void _addNote() async {
    if (widget.selectedCarId == null) return;
    final result = await Navigator.push<ProfileNote>(context,
      MaterialPageRoute(builder: (_) => _EditNoteScreen(carId: widget.selectedCarId)));
    if (result != null && mounted) {
      ref.read(profileNotesProvider.notifier).add(result);
    }
  }

  void _editNote(ProfileNote note) async {
    final result = await Navigator.push<ProfileNote>(context,
      MaterialPageRoute(builder: (_) => _EditNoteScreen(note: note, carId: note.carId)));
    if (result != null && mounted) {
      ref.read(profileNotesProvider.notifier).update(result);
    }
  }

  void _removeNote(ProfileNote note) {
    ref.read(profileNotesProvider.notifier).remove(note.id);
  }

  @override
  Widget build(BuildContext context) {
    final notes = _notes;
    final noCar = widget.selectedCarId == null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Заметки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          if (!noCar) IconButton(onPressed: _addNote, icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: noCar
          ? const EmptyState(
              icon: '🚗',
              title: 'Выберите автомобиль',
              subtitle: 'В профиле в блоке «Мои автомобили» выберите авто, чтобы видеть и добавлять заметки',
            )
          : notes.isEmpty
              ? EmptyState(
                  icon: '📝',
                  title: 'Нет заметок',
                  subtitle: 'Добавьте заметку о вашем авто',
                  buttonText: '+ Добавить',
                  onButton: _addNote,
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final n = notes[i];
                    return Dismissible(
                      key: ValueKey(n.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete_rounded, color: Colors.white),
                      ),
                      onDismissed: (_) => _removeNote(n),
                      child: GestureDetector(
                        onTap: () => _editNote(n),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(n.title, style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                                    ), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  Text('${n.date.day}.${n.date.month.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(n.body, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: noCar ? null : FloatingActionButton(
        onPressed: _addNote,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Color(0xFF0D0D0D)),
      ),
    );
  }
}

class _EditNoteScreen extends StatefulWidget {
  final ProfileNote? note;
  final String? carId;

  const _EditNoteScreen({this.note, this.carId});

  @override
  State<_EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<_EditNoteScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _bodyController = TextEditingController(text: widget.note?.body ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final date = DateTime.now();
    if (widget.note != null) {
      Navigator.pop(context, ProfileNote(
        id: widget.note!.id,
        carId: widget.note!.carId,
        title: title,
        body: body,
        date: date,
      ));
    } else if (widget.carId != null) {
      Navigator.pop(context, ProfileNote(
        id: 'note_${date.millisecondsSinceEpoch}',
        carId: widget.carId!,
        title: title,
        body: body,
        date: date,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(widget.note == null ? 'Новая заметка' : 'Редактировать',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Заголовок',
                hintStyle: TextStyle(color: AppColors.textPlaceholder),
                border: InputBorder.none,
              ),
              autofocus: widget.note == null,
            ),
            const Divider(color: AppColors.border),
            Expanded(
              child: TextField(
                controller: _bodyController,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Текст заметки...',
                  hintStyle: TextStyle(color: AppColors.textPlaceholder),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
