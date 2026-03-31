import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../shared/models/settings_models.dart';

class ServiceCategoryEditScreen extends ConsumerStatefulWidget {
  final ServiceCategory category;

  const ServiceCategoryEditScreen({super.key, required this.category});

  @override
  ConsumerState<ServiceCategoryEditScreen> createState() => _ServiceCategoryEditScreenState();
}

class _ServiceCategoryEditScreenState extends ConsumerState<ServiceCategoryEditScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Редактировать категорию'),
        actions: [
          TextButton(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isNotEmpty) {
                ref.read(settingsRepositoryProvider.notifier).updateCategory(
                      widget.category.copyWith(name: name),
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Название категории',
          ),
        ),
      ),
    );
  }
}
