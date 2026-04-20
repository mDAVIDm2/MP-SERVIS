import 'package:flutter/material.dart';
import '../../../../core/api/reference_api_service.dart';
import '../../../../core/theme/client_palette.dart';

/// Маркер пункта «Другое» в списке автодополнения.
class CarReferencePickOther {
  const CarReferencePickOther();
}

/// Одна строка: ввод фильтра и выбор из выпадающего списка (как Autocomplete).
class CarReferenceAutocompleteField<T extends Object> extends StatelessWidget {
  const CarReferenceAutocompleteField({
    super.key,
    required this.label,
    required this.hint,
    required this.enabled,
    required this.optionsBuilder,
    required this.displayStringForOption,
    required this.onSelected,
    required this.optionTitle,
    this.optionSubtitle,
    this.optionsMaxHeight = 280,
  });

  final String label;
  final String hint;
  final bool enabled;
  final Iterable<T> Function(TextEditingValue textEditingValue) optionsBuilder;
  final String Function(T option) displayStringForOption;
  final void Function(T option) onSelected;
  final String Function(T option) optionTitle;
  final String? Function(T option)? optionSubtitle;
  final double optionsMaxHeight;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: context.palette.textSecondary)),
          SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: context.palette.cardBg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.palette.border.withValues(alpha: 0.5)),
            ),
            child: Text(
              hint,
              style: TextStyle(fontSize: 16, color: context.palette.textPlaceholder.withValues(alpha: 0.8)),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: context.palette.textSecondary)),
        SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            return RawAutocomplete<T>(
              displayStringForOption: displayStringForOption,
              optionsBuilder: optionsBuilder,
              onSelected: onSelected,
              fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                return Container(
                  decoration: BoxDecoration(
                    color: context.palette.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: focusNode.hasFocus ? context.palette.primary : context.palette.border,
                    ),
                  ),
                  child: TextField(
                    controller: textController,
                    focusNode: focusNode,
                    onSubmitted: (_) => onFieldSubmitted(),
                    scrollPadding: const EdgeInsets.fromLTRB(0, 80, 0, 320),
                    style: TextStyle(fontSize: 16, color: context.palette.textPrimary),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(color: context.palette.textPlaceholder),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      suffixIcon: Icon(
                        Icons.arrow_drop_down_rounded,
                        color: context.palette.textTertiary,
                        size: 28,
                      ),
                    ),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                final mq = MediaQuery.of(context);
                final kb = mq.viewInsets.bottom;
                final screenH = mq.size.height;
                // Окно списка над клавиатурой: ограничиваем высоту по видимой области.
                final maxListH = (screenH - kb - mq.padding.top - 120).clamp(160.0, optionsMaxHeight);
                return Padding(
                  padding: EdgeInsets.only(bottom: kb),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      color: context.palette.cardBg,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxListH),
                        child: options.isEmpty
                            ? Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Ничего не найдено',
                                  style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
                                ),
                              )
                            : Scrollbar(
                                thumbVisibility: options.length > 6,
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  primary: false,
                                  shrinkWrap: false,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: options.length,
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    color: context.palette.border.withValues(alpha: 0.6),
                                  ),
                                  itemBuilder: (context, index) {
                                    final option = options.elementAt(index);
                                    final sub = optionSubtitle?.call(option);
                                    return ListTile(
                                      dense: true,
                                      title: Text(
                                        optionTitle(option),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: context.palette.textPrimary,
                                        ),
                                      ),
                                      subtitle: sub != null && sub.isNotEmpty
                                          ? Text(
                                              sub,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: context.palette.textSecondary,
                                              ),
                                            )
                                          : null,
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// Марка: [CarBrandDto] + [CarReferencePickOther].
Widget buildBrandAutocompleteField({
  required List<CarBrandDto> brands,
  required CarBrandDto? selectedBrand,
  required void Function(CarBrandDto brand) onPickBrand,
  required VoidCallback onPickOther,
}) {
  return CarReferenceAutocompleteField<Object>(
    label: 'Марка *',
    hint: 'Начните вводить или выберите из списка',
    enabled: brands.isNotEmpty,
    displayStringForOption: (o) {
      if (o is CarBrandDto) return o.name;
      if (o is CarReferencePickOther) return 'Другое (указать вручную)';
      return '';
    },
    optionTitle: (o) {
      if (o is CarBrandDto) return o.name;
      return 'Другое (указать вручную)';
    },
    optionsBuilder: (tev) {
      final q = tev.text.trim().toLowerCase();
      final all = List<CarBrandDto>.from(brands);
      all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      var list = q.isEmpty
          ? all
          : all.where((b) => b.name.toLowerCase().contains(q)).toList();
      if (selectedBrand != null && !list.any((b) => b.id == selectedBrand.id)) {
        list = [selectedBrand, ...list];
      }
      return [...list, const CarReferencePickOther()];
    },
    onSelected: (o) {
      if (o is CarReferencePickOther) {
        onPickOther();
      } else if (o is CarBrandDto) {
        onPickBrand(o);
      }
    },
  );
}

/// Модель: [CarModelDto] + [CarReferencePickOther].
Widget buildModelAutocompleteField({
  required List<CarModelDto> models,
  required CarModelDto? selectedModel,
  required void Function(CarModelDto model) onPickModel,
  required VoidCallback onPickOther,
}) {
  return CarReferenceAutocompleteField<Object>(
    label: 'Модель *',
    hint: 'Начните вводить или выберите из списка',
    enabled: models.isNotEmpty,
    displayStringForOption: (o) {
      if (o is CarModelDto) return o.name;
      if (o is CarReferencePickOther) return 'Другое (указать вручную)';
      return '';
    },
    optionTitle: (o) {
      if (o is CarModelDto) return o.name;
      return 'Другое (указать вручную)';
    },
    optionsBuilder: (tev) {
      final q = tev.text.trim().toLowerCase();
      final all = List<CarModelDto>.from(models);
      all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      var list = q.isEmpty
          ? all
          : all.where((m) => m.name.toLowerCase().contains(q)).toList();
      if (selectedModel != null && !list.any((m) => m.id == selectedModel.id)) {
        list = [selectedModel, ...list];
      }
      return [...list, const CarReferencePickOther()];
    },
    onSelected: (o) {
      if (o is CarReferencePickOther) {
        onPickOther();
      } else if (o is CarModelDto) {
        onPickModel(o);
      }
    },
  );
}

/// Поколение: [CarGenerationDto] + [CarReferencePickOther].
Widget buildGenerationAutocompleteField({
  required List<CarGenerationDto> generations,
  required CarGenerationDto? selectedGeneration,
  required void Function(CarGenerationDto gen) onPickGeneration,
  required VoidCallback onPickOther,
}) {
  return CarReferenceAutocompleteField<Object>(
    label: 'Поколение (необязательно)',
    hint: 'Фильтр или выбор из списка',
    enabled: generations.isNotEmpty,
    displayStringForOption: (o) {
      if (o is CarGenerationDto) {
        return o.yearRange.isNotEmpty ? '${o.name} (${o.yearRange})' : o.name;
      }
      if (o is CarReferencePickOther) return 'Другое (указать вручную)';
      return '';
    },
    optionTitle: (o) {
      if (o is CarGenerationDto) return o.name;
      return 'Другое (указать вручную)';
    },
    optionSubtitle: (o) {
      if (o is CarGenerationDto && o.yearRange.isNotEmpty) return o.yearRange;
      return null;
    },
    optionsBuilder: (tev) {
      final q = tev.text.trim().toLowerCase();
      final all = List<CarGenerationDto>.from(generations);
      all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      var list = q.isEmpty
          ? all
          : all.where((g) {
              final inName = g.name.toLowerCase().contains(q);
              final inYears = g.yearRange.toLowerCase().contains(q);
              return inName || inYears;
            }).toList();
      if (selectedGeneration != null && !list.any((g) => g.id == selectedGeneration.id)) {
        list = [selectedGeneration, ...list];
      }
      return [...list, const CarReferencePickOther()];
    },
    onSelected: (o) {
      if (o is CarReferencePickOther) {
        onPickOther();
      } else if (o is CarGenerationDto) {
        onPickGeneration(o);
      }
    },
  );
}
