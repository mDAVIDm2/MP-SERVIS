import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/maintenance_reminders_provider.dart';
import '../../../../core/api/reference_api_service.dart';
import '../../../../core/api/car_reference_data.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../core/utils/vin_validation.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/russian_license_plate_field.dart';
import '../widgets/car_reference_autocomplete_field.dart';

class AddCarScreen extends ConsumerStatefulWidget {
  const AddCarScreen({super.key, this.editCarId});

  /// Если задан — только шаг марка/модель/поколение: исправить данные существующей машины (после отклонения заявки и т.п.).
  final String? editCarId;

  @override
  ConsumerState<AddCarScreen> createState() => _AddCarScreenState();
}

class _AddCarScreenState extends ConsumerState<AddCarScreen> {
  int _step = 0;
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _plateController = TextEditingController();
  final _vinController = TextEditingController();
  final _mileageController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _colorController = TextEditingController();
  final _customGenerationController = TextEditingController();
  String? _selectedEngine;
  String? _selectedTransmission;
  String? _selectedDrivetrain;
  String? _selectedBodyType;

  /// Справочник марок/моделей: с API или встроенный (если API недоступен).
  List<CarBrandDto>? _brands;
  List<CarModelDto>? _models;
  List<CarGenerationDto>? _generations;
  CarBrandDto? _selectedBrand;
  CarModelDto? _selectedModel;
  CarGenerationDto? _selectedGeneration;
  bool _brandsLoading = false;
  bool _modelsLoading = false;
  bool _generationsLoading = false;
  bool _usingBundledData = false;

  /// Ввод вручную: марка/модель/поколение не из списка (ожидают подтверждения разработчиками).
  bool _brandOther = false;
  bool _modelOther = false;
  bool _generationOther = false;

  /// Защита от повторных нажатий «Сохранить» пока идёт запись и запрос к API.
  bool _saving = false;

  /// Локальный путь к фото до сохранения машины (после сохранения загружается через updateCarPhoto).
  String? _pickedPhotoPath;

  bool _editSeeded = false;

  static const int kMinCarYear = 1950;

  /// Пресеты цвета: свотч + строка для API (пользователь может изменить текст вручную).
  static const List<({Color swatch, String name})> _kColorPresets = [
    (swatch: Color(0xFFF5F5F5), name: 'Белый'),
    (swatch: Color(0xFF1A1A1A), name: 'Чёрный'),
    (swatch: Color(0xFFC0C0C0), name: 'Серебристый'),
    (swatch: Color(0xFF757575), name: 'Серый'),
    (swatch: Color(0xFFE53935), name: 'Красный'),
    (swatch: Color(0xFF1976D2), name: 'Синий'),
    (swatch: Color(0xFF2E7D32), name: 'Зелёный'),
    (swatch: Color(0xFF6D4C41), name: 'Коричневый'),
    (swatch: Color(0xFFD7CCC8), name: 'Бежевый'),
    (swatch: Color(0xFFFDD835), name: 'Жёлтый'),
    (swatch: Color(0xFFFF9800), name: 'Оранжевый'),
    (swatch: Color(0xFF7B1FA2), name: 'Фиолетовый'),
  ];

  /// Индекс выбранного пресета или null, если введён свой текст.
  int? _selectedColorPresetIndex;

  final _engines = ['Бензин', 'Дизель', 'Гибрид', 'Электро', 'Газ'];
  final _transmissions = ['Автомат', 'Механика', 'Робот', 'Вариатор'];
  final _drivetrains = ['Передний', 'Задний', 'Полный'];
  final _bodyTypes = [
    'Седан',
    'Хэтчбек',
    'Универсал',
    'Кроссовер',
    'Внедорожник',
    'Купе',
    'Минивэн',
    'Пикап',
    'Фургон',
  ];

  final _steps = [
    'Марка и модель',
    'Год и VIN',
    'Двигатель',
    'Пробег',
    'Готово',
  ];

  bool get _isEditMode =>
      widget.editCarId != null && widget.editCarId!.trim().isNotEmpty;

  List<String> get _effectiveSteps =>
      _isEditMode ? const ['Марка и модель'] : _steps;

  int get _maxCarYear => DateTime.now().year;

  bool _yearValid() {
    final s = _yearController.text.trim();
    if (s.length != 4) return false;
    final y = int.tryParse(s);
    if (y == null) return false;
    return y >= kMinCarYear && y <= _maxCarYear;
  }

  /// Рамка поля года: зелёный при 4 верных цифрах, красный при полном но неверном годе, иначе нейтрально.
  Color? _yearFieldBorderColor() {
    final s = _yearController.text.trim();
    if (s.length != 4) return null;
    return _yearValid() ? context.palette.success : context.palette.error;
  }

  Color? _plateFieldBorderColor() {
    final plate = normalizePlateInput(_plateController.text);
    if (plate.isEmpty) return null;
    return isValidRussianPlateCompact(plate) ? context.palette.success : context.palette.error;
  }

  Color? _vinFieldBorderColor() {
    final t = _vinController.text.trim();
    if (t.isEmpty) return null;
    return vinValidationMessageRu(_vinController.text) == null
        ? context.palette.success
        : context.palette.error;
  }

  Color? _mileageFieldBorderColor() {
    final s = _mileageController.text.replaceAll(' ', '').trim();
    if (s.isEmpty) return null;
    final n = int.tryParse(s);
    return (n != null && n >= 0) ? context.palette.success : context.palette.error;
  }

  void _syncColorPresetIndexFromText(String text) {
    final t = text.trim().toLowerCase();
    int? idx;
    for (var i = 0; i < _kColorPresets.length; i++) {
      if (_kColorPresets[i].name.toLowerCase() == t) {
        idx = i;
        break;
      }
    }
    _selectedColorPresetIndex = idx;
  }

  bool get _useReference => _brands != null && _brands!.isNotEmpty;

  /// Нужна ли заявка разработчикам (ручной ввод или поколение вне справочника).
  bool _needsReferenceModeration({
    required int? brandId,
    required int? modelId,
    required int? generationId,
    required String brandName,
    required String modelName,
    required String? generation,
  }) {
    final bn = brandName.trim();
    final mn = modelName.trim();
    final g = generation?.trim() ?? '';
    return (brandId == null && bn.isNotEmpty) ||
        (modelId == null && mn.isNotEmpty && mn != '—') ||
        (generationId == null && g.isNotEmpty);
  }

  /// Тексты марки/модели/поколения из формы — не из ответа API (там иногда пустые строки при тех же id).
  Future<bool> _submitPendingFromForm({
    required String carId,
    required String brandName,
    required String modelName,
    required String? generation,
    required int? brandId,
    required int? modelId,
    required int? generationId,
  }) async {
    if (!_needsReferenceModeration(
      brandId: brandId,
      modelId: modelId,
      generationId: generationId,
      brandName: brandName,
      modelName: modelName,
      generation: generation,
    )) {
      return true;
    }
    final mn = modelName.trim();
    final g = generation?.trim() ?? '';
    final pendingRes = await ref.read(referenceApiServiceProvider).submitPendingCar(
          carId: carId,
          pendingBrand: brandName.trim().isNotEmpty ? brandName.trim() : null,
          pendingModel: mn.isNotEmpty && mn != '—' ? mn : null,
          pendingGeneration: generationId == null && g.isNotEmpty ? g : null,
          referenceBrandId: brandId,
          referenceModelId: modelId,
        );
    return pendingRes.errorOrNull == null;
  }

  bool get _canProceed {
    switch (_step) {
      case 0:
        if (_useReference) {
          final brandOk =
              _selectedBrand != null ||
              (_brandOther && _brandController.text.trim().isNotEmpty);
          // При выборе «Другое» для марки оба поля — ручной ввод; при выборе марки из списка модель может быть из списка или «Другое»
          final modelOk =
              _selectedModel != null ||
              (_modelOther && _modelController.text.trim().isNotEmpty) ||
              (_brandOther && _modelController.text.trim().isNotEmpty);
          return brandOk && modelOk;
        }
        return _brandController.text.trim().isNotEmpty &&
            _modelController.text.trim().isNotEmpty;
      case 1:
        {
          final plate = normalizePlateInput(_plateController.text);
          final plateOk = plate.isEmpty || isValidRussianPlateCompact(plate);
          return _yearController.text.trim().length == 4 &&
              _yearValid() &&
              plateOk;
        }
      case 2:
        return _selectedEngine != null && _selectedBodyType != null;
      case 3:
        return _mileageController.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  String get _summaryGenerationSuffix {
    if (!_useReference) return '';
    String? gen;
    if (_generationOther || _brandOther || _modelOther) {
      final t = _customGenerationController.text.trim();
      if (t.isNotEmpty) gen = t;
    } else if (_selectedGeneration != null) {
      gen = _selectedGeneration!.name;
    }
    if (gen == null || gen.isEmpty) return '';
    return ' ($gen)';
  }

  @override
  void initState() {
    super.initState();
    _loadBrands();
    if (_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref.read(carsProvider.notifier).loadCars(silent: true);
        if (mounted) await _trySeedEditCar();
      });
    }
  }

  Future<void> _loadBrands() async {
    setState(() => _brandsLoading = true);
    final result = await ref.read(referenceApiServiceProvider).getCarBrands();
    if (!mounted) return;
    final fromApi = result.dataOrNull;
    final useBundled = fromApi == null || fromApi.isEmpty;
    final raw = useBundled
        ? CarReferenceData.bundledBrands
        : List<CarBrandDto>.from(fromApi);
    raw.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _brandsLoading = false;
      _brands = raw;
      _usingBundledData = useBundled;
    });
    if (_isEditMode && mounted) {
      await _trySeedEditCar();
    }
  }

  void _applyManualBrandModelFromCar(Car car) {
    _brandOther = true;
    _selectedBrand = null;
    _modelOther = false;
    _selectedModel = null;
    _selectedGeneration = null;
    _generationOther = false;
    _models = null;
    _generations = null;
    _brandController.text = car.brand;
    _modelController.text = car.model;
    final g = car.generation?.trim() ?? '';
    if (g.isNotEmpty) {
      _generationOther = true;
      _customGenerationController.text = g;
    } else {
      _generationOther = false;
      _customGenerationController.clear();
    }
  }

  Future<void> _trySeedEditCar() async {
    if (!_isEditMode || _editSeeded || _brands == null || _brands!.isEmpty) {
      return;
    }
    final id = widget.editCarId!.trim();
    final cars = ref.read(carsProvider).valueOrNull ?? [];
    Car? car;
    for (final c in cars) {
      if (c.id == id) {
        car = c;
        break;
      }
    }
    if (car == null) {
      _editSeeded = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Автомобиль не найден в гараже. Обновите список и откройте экран снова.',
            ),
            backgroundColor: context.palette.error,
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    _nicknameController.text = car.nickname ?? '';

    if (car.brandId != null) {
      CarBrandDto? b;
      for (final x in _brands!) {
        if (x.id == car.brandId) {
          b = x;
          break;
        }
      }
      if (b != null) {
        _brandOther = false;
        _selectedBrand = b;
        await _loadModels(b.id);
        if (!mounted) return;
        if (car.modelId != null && _models != null) {
          CarModelDto? m;
          for (final x in _models!) {
            if (x.id == car.modelId) {
              m = x;
              break;
            }
          }
          if (m != null) {
            _modelOther = false;
            _selectedModel = m;
            await _loadGenerations();
            if (!mounted) return;
            if (car.generationId != null && _generations != null) {
              CarGenerationDto? g;
              for (final x in _generations!) {
                if (x.id == car.generationId) {
                  g = x;
                  break;
                }
              }
              if (g != null) {
                _generationOther = false;
                _selectedGeneration = g;
                _customGenerationController.clear();
              } else {
                _generationOther = true;
                _selectedGeneration = null;
                _customGenerationController.text = car.generation?.trim() ?? '';
              }
            } else {
              final gt = car.generation?.trim() ?? '';
              if (gt.isNotEmpty) {
                _generationOther = true;
                _selectedGeneration = null;
                _customGenerationController.text = gt;
              } else {
                _generationOther = false;
                _selectedGeneration = null;
                _customGenerationController.clear();
              }
            }
          } else {
            _modelOther = true;
            _selectedModel = null;
            _modelController.text = car.model;
            final gt = car.generation?.trim() ?? '';
            if (gt.isNotEmpty) {
              _generationOther = true;
              _customGenerationController.text = gt;
            } else {
              _generationOther = false;
              _customGenerationController.clear();
            }
          }
        } else {
          _modelOther = true;
          _selectedModel = null;
          _modelController.text = car.model;
          final gt = car.generation?.trim() ?? '';
          if (gt.isNotEmpty) {
            _generationOther = true;
            _customGenerationController.text = gt;
          } else {
            _generationOther = false;
            _customGenerationController.clear();
          }
        }
      } else {
        _applyManualBrandModelFromCar(car);
      }
    } else {
      _applyManualBrandModelFromCar(car);
    }

    _editSeeded = true;
    if (mounted) setState(() {});
  }

  Future<void> _loadModels(int brandId) async {
    setState(() {
      _selectedModel = null;
      _selectedGeneration = null;
      _generations = null;
      _models = null;
      _modelsLoading = !_usingBundledData;
    });
    if (_usingBundledData) {
      if (!mounted) return;
      final m = CarReferenceData.modelsForBrand(brandId);
      m.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _models = m;
        _modelsLoading = false;
      });
      return;
    }
    final result = await ref
        .read(referenceApiServiceProvider)
        .getCarModels(brandId);
    if (!mounted) return;
    final m = List<CarModelDto>.from(result.dataOrNull ?? []);
    m.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _modelsLoading = false;
      _models = m;
    });
  }

  Future<void> _loadGenerations() async {
    if (_selectedBrand == null || _selectedModel == null) return;
    setState(() {
      _selectedGeneration = null;
      _generations = null;
      _generationsLoading = !_usingBundledData;
    });
    if (_usingBundledData) {
      if (!mounted) return;
      final list = CarReferenceData.generationsForModel(
        _selectedBrand!.name,
        _selectedModel!.name,
      );
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _generations = list;
        _generationsLoading = false;
        if (list.isEmpty && !_modelOther && !_brandOther) {
          _generationOther = true;
          _selectedGeneration = null;
        }
      });
      return;
    }
    final result = await ref
        .read(referenceApiServiceProvider)
        .getCarGenerations(_selectedModel!.id);
    if (!mounted) return;
    final gens = List<CarGenerationDto>.from(result.dataOrNull ?? []);
    gens.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _generationsLoading = false;
      _generations = gens;
      if (gens.isEmpty && _selectedModel != null && !_modelOther && !_brandOther) {
        _generationOther = true;
        _selectedGeneration = null;
      }
    });
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _vinController.dispose();
    _mileageController.dispose();
    _nicknameController.dispose();
    _colorController.dispose();
    _customGenerationController.dispose();
    super.dispose();
  }

  Future<void> _saveEditReference() async {
    if (!_isEditMode || !_canProceed || _saving) return;
    setState(() => _saving = true);
    try {
      HapticFeedback.heavyImpact();
      final brandName = _useReference
          ? (_brandOther
              ? _brandController.text.trim()
              : (_selectedBrand?.name ?? ''))
          : _brandController.text.trim();
      final modelName = _useReference
          ? (_modelOther || _brandOther
              ? _modelController.text.trim()
              : (_selectedModel?.name ?? ''))
          : _modelController.text.trim();
      final generation = _useReference
          ? ((_generationOther || _brandOther || _modelOther)
              ? (_customGenerationController.text.trim().isEmpty
                  ? null
                  : _customGenerationController.text.trim())
              : _selectedGeneration?.name)
          : null;
      final brandId = _useReference && !_brandOther ? _selectedBrand?.id : null;
      final modelId = _useReference && !_modelOther ? _selectedModel?.id : null;
      final generationId =
          _useReference && !_generationOther && !_brandOther && !_modelOther
              ? _selectedGeneration?.id
              : null;
      final nick = _nicknameController.text.trim();

      final car = await ref.read(carsProvider.notifier).patchCarGarageReference(
            widget.editCarId!.trim(),
            brand: brandName,
            model: modelName,
            generation: generation,
            brandId: brandId,
            modelId: modelId,
            generationId: generationId,
            nickname: nick.isEmpty ? null : nick,
          );

      if (!mounted) return;

      if (car == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Не удалось сохранить данные. Проверьте сеть и войдите в аккаунт.'),
            backgroundColor: context.palette.error,
          ),
        );
        return;
      }

      final pendingOk = await _submitPendingFromForm(
        carId: car.id,
        brandName: brandName,
        modelName: modelName,
        generation: generation,
        brandId: brandId,
        modelId: modelId,
        generationId: generationId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pendingOk
                ? 'Данные авто обновлены. При необходимости заявка снова отправлена разработчикам.'
                : 'Данные сохранены. Заявка модераторам не дошла — проверьте сеть.',
          ),
          backgroundColor: pendingOk ? context.palette.success : Colors.orange.shade800,
        ),
      );
      Navigator.pop(context, car.id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handlePrimary() async {
    if (!_canProceed || _saving) return;

    if (_step < _effectiveSteps.length - 1) {
      setState(() => _step++);
      return;
    }

    if (_isEditMode) {
      await _saveEditReference();
      return;
    }

    setState(() => _saving = true);
    try {
      HapticFeedback.heavyImpact();

      if (!_yearValid()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Год выпуска: с $kMinCarYear по $_maxCarYear'),
            ),
          );
        }
        return;
      }

      final plateCompact = normalizePlateInput(_plateController.text);
      if (plateCompact.isNotEmpty &&
          !isValidRussianPlateCompact(plateCompact)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Госномер: введите полностью (А123АА777) или оставьте пустым',
              ),
            ),
          );
        }
        return;
      }

      final vinErr = vinValidationMessageRu(_vinController.text);
      if (vinErr != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(vinErr)));
        }
        return;
      }
      final vinNorm = normalizeVinOrNull(_vinController.text);

      final year = int.parse(_yearController.text.trim());
      final mileage =
          int.tryParse(_mileageController.text.replaceAll(' ', '')) ?? 0;
      final brandName = _useReference
          ? (_brandOther
                ? _brandController.text.trim()
                : (_selectedBrand?.name ?? ''))
          : _brandController.text.trim();
      final modelName = _useReference
          ? (_modelOther || _brandOther
                ? _modelController.text.trim()
                : (_selectedModel?.name ?? ''))
          : _modelController.text.trim();
      final generation = _useReference
          ? ((_generationOther || _brandOther || _modelOther)
                ? (_customGenerationController.text.trim().isEmpty
                      ? null
                      : _customGenerationController.text.trim())
                : _selectedGeneration?.name)
          : null;
      final brandId = _useReference && !_brandOther ? _selectedBrand?.id : null;
      final modelId = _useReference && !_modelOther ? _selectedModel?.id : null;
      final generationId =
          _useReference && !_generationOther && !_brandOther && !_modelOther
          ? _selectedGeneration?.id
          : null;

      final car = await ref
          .read(carsProvider.notifier)
          .addCar(
            brandName: brandName,
            modelName: modelName,
            generation: generation,
            brandId: brandId,
            modelId: modelId,
            generationId: generationId,
            year: year,
            licensePlate: plateCompact.isEmpty ? null : plateCompact,
            mileage: mileage,
            vin: vinNorm,
            nickname: _nicknameController.text.trim().isEmpty
                ? null
                : _nicknameController.text.trim(),
            engineType: _selectedEngine,
            transmission: _selectedTransmission,
            drivetrain: _selectedDrivetrain,
            bodyType: _selectedBodyType,
            color: _colorController.text.trim().isEmpty
                ? null
                : _colorController.text.trim(),
          );

      if (!mounted) return;

      if (car == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось сохранить автомобиль. Войдите в аккаунт и попробуйте снова.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      ref.read(maintenanceRemindersProvider.notifier).ensureStandardRemindersForCar(car.id);
      final photoPath = _pickedPhotoPath;
      if (photoPath != null && photoPath.isNotEmpty) {
        await ref.read(carsProvider.notifier).updateCarPhoto(car.id, photoPath);
      }

      final pendingOk = await _submitPendingFromForm(
        carId: car.id,
        brandName: brandName,
        modelName: modelName,
        generation: generation,
        brandId: brandId,
        modelId: modelId,
        generationId: generationId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pendingOk
                ? '$brandName $modelName добавлен в гараж на этом устройстве. '
                    'Переустановка приложения сотрёт локальный гараж, пока нет облачной синхронизации.'
                : '$brandName $modelName сохранён. Заявка модераторам не дошла — проверьте сеть и попробуйте позже.',
          ),
          backgroundColor: pendingOk
              ? context.palette.success
              : Colors.orange.shade800,
        ),
      );
      Navigator.pop(context, car.id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        title: Text(
          _isEditMode
              ? 'Марка, модель и поколение'
              : _effectiveSteps[_step],
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          if (!_isEditMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: List.generate(
                  _effectiveSteps.length,
                  (i) => Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= _step
                            ? context.palette.primary
                            : context.palette.nestedBg,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStep(),
              ),
            ),
          ),

          // Buttons
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              children: [
                if (_step > 0)
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        side: BorderSide(color: context.palette.border),
                      ),
                      child: Text('Назад'),
                    ),
                  ),
                if (_step > 0) SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GoldButton(
                    text: _step == _effectiveSteps.length - 1
                        ? (_saving ? 'Сохранение…' : 'Сохранить')
                        : 'Далее',
                    height: 52,
                    isLoading: _saving && _step == _effectiveSteps.length - 1,
                    onPressed: (_canProceed && !_saving)
                        ? () {
                            _handlePrimary();
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildBrandModel();
      case 1:
        return _buildYearVin();
      case 2:
        return _buildEngine();
      case 3:
        return _buildMileage();
      case 4:
        return _buildSummary();
      default:
        return SizedBox();
    }
  }

  Widget _buildBrandModel() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8),
        if (_brandsLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_useReference) ...[
          if (!_brandOther)
            KeyedSubtree(
              // Только длина списка марок: не включаем выбранную марку — иначе после выбора ключ
              // меняется, RawAutocomplete пересоздаётся и поле «сбрасывается» (нужно выбирать снова).
              key: ValueKey<String>('brand_${_brands?.length ?? 0}'),
              child: buildBrandAutocompleteField(
                brands: _brands!,
                selectedBrand: _selectedBrand,
                onPickBrand: (brand) {
                  setState(() {
                    _brandOther = false;
                    _selectedBrand = brand;
                    _modelOther = false;
                    _selectedModel = null;
                    _selectedGeneration = null;
                    _generationOther = false;
                    _generations = null;
                  });
                  _loadModels(brand.id);
                },
                onPickOther: () {
                  setState(() {
                    _brandOther = true;
                    _selectedBrand = null;
                    _modelOther = false;
                    _selectedModel = null;
                    _selectedGeneration = null;
                    _generationOther = false;
                    _models = null;
                    _generations = null;
                  });
                },
              ),
            )
          else ...[
            _buildField('Марка (вручную) *', _brandController, 'Например: BMW'),
            SizedBox(height: 16),
            _buildField('Модель (вручную) *', _modelController, 'Например: X5'),
            SizedBox(height: 16),
            _buildField(
              'Поколение (вручную, необязательно)',
              _customGenerationController,
              'Например: XV70',
            ),
          ],
          if (!_brandOther) SizedBox(height: 16),
          if (_selectedBrand != null && !_brandOther)
            _modelsLoading
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_modelOther)
                        KeyedSubtree(
                          // Марка + длина списка моделей; без id выбранной модели — иначе после выбора
                          // виджет пересоздаётся и нужно тапать повторно.
                          key: ValueKey<String>('model_${_selectedBrand!.id}_${_models?.length ?? 0}'),
                          child: buildModelAutocompleteField(
                            models: _models ?? const [],
                            selectedModel: _selectedModel,
                            onPickModel: (model) {
                              setState(() {
                                _modelOther = false;
                                _selectedModel = model;
                                _generationOther = false;
                                _selectedGeneration = null;
                              });
                              _loadGenerations();
                            },
                            onPickOther: () {
                              setState(() {
                                _modelOther = true;
                                _selectedModel = null;
                                _generationOther = false;
                                _selectedGeneration = null;
                                _generations = null;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
          if (_modelOther && !_brandOther) ...[
            SizedBox(height: 16),
            _buildField('Модель (вручную) *', _modelController, 'Например: X5'),
            SizedBox(height: 16),
            _buildField(
              'Поколение (вручную, необязательно)',
              _customGenerationController,
              'Например: XV70',
            ),
          ],
          if (_selectedModel != null && !_modelOther) ...[
            if (_generationsLoading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_generations != null && _generations!.isNotEmpty) ...[
              SizedBox(height: 16),
              if (!_generationOther)
                KeyedSubtree(
                  // Модель + число поколений; без id поколения — иначе после выбора сброс поля.
                  key: ValueKey<String>('gen_${_selectedModel!.id}_${_generations!.length}'),
                  child: buildGenerationAutocompleteField(
                    generations: _generations!,
                    selectedGeneration: _selectedGeneration,
                    onPickGeneration: (gen) {
                      setState(() {
                        _generationOther = false;
                        _selectedGeneration = gen;
                      });
                    },
                    onPickOther: () {
                      setState(() {
                        _generationOther = true;
                        _selectedGeneration = null;
                      });
                    },
                  ),
                ),
            ]
            else if (_generations != null && _generations!.isEmpty) ...[
              SizedBox(height: 16),
              Text(
                'Поколений этой модели нет в справочнике. Укажите поколение вручную — заявку проверят разработчики.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.palette.textSecondary.withValues(alpha: 0.95),
                  height: 1.4,
                ),
              ),
            ],
            if (_generationOther) ...[
              SizedBox(height: 16),
              _buildField(
                'Поколение (вручную)',
                _customGenerationController,
                'Например: XV70',
              ),
            ],
          ],
        ] else ...[
          _buildField('Марка *', _brandController, 'Например: BMW'),
          SizedBox(height: 16),
          _buildField('Модель *', _modelController, 'Например: X5'),
        ],
        SizedBox(height: 16),
        _buildField(
          'Никнейм (необязательно)',
          _nicknameController,
          'Например: Чёрный зверь',
        ),
      ],
    );
  }

  Widget _buildYearVin() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8),
        _buildField(
          'Год выпуска *',
          _yearController,
          '2024',
          keyboardType: TextInputType.number,
          validationBorderColor: _yearFieldBorderColor(),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
        ),
        SizedBox(height: 4),
        Text(
          'Год: с $kMinCarYear по $_maxCarYear',
          style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
        ),
        SizedBox(height: 12),
        RussianLicensePlateField(
          controller: _plateController,
          validationBorderColor: _plateFieldBorderColor(),
        ),
        SizedBox(height: 16),
        _buildField(
          'VIN (необязательно)',
          _vinController,
          'Только A–Z и 0–9, до 32 символов',
          validationBorderColor: _vinFieldBorderColor(),
          inputFormatters: [
            VinUpperCaseTextInputFormatter(),
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(32),
          ],
        ),
      ],
    );
  }

  Widget _buildEngine() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8),
        Text(
          'Тип двигателя *',
          style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _engines.map((e) {
            final isSelected = _selectedEngine == e;
            return GestureDetector(
              onTap: () => setState(() => _selectedEngine = e),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? context.palette.primary : context.palette.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? context.palette.primary : context.palette.border,
                  ),
                ),
                child: Text(
                  e,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? context.palette.onAccent
                        : context.palette.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 24),
        Text(
          'Коробка передач',
          style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _transmissions.map((t) {
            final isSelected = _selectedTransmission == t;
            return GestureDetector(
              onTap: () => setState(() => _selectedTransmission = t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? context.palette.primary : context.palette.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? context.palette.primary : context.palette.border,
                  ),
                ),
                child: Text(
                  t,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? context.palette.onAccent
                        : context.palette.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 24),
        _buildColorSection(),
        SizedBox(height: 24),
        Text(
          'Привод',
          style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _drivetrains.map((d) {
            final isSelected = _selectedDrivetrain == d;
            return GestureDetector(
              onTap: () => setState(() => _selectedDrivetrain = d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? context.palette.primary : context.palette.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? context.palette.primary : context.palette.border,
                  ),
                ),
                child: Text(
                  d,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? context.palette.onAccent
                        : context.palette.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 24),
        Text(
          'Тип кузова *',
          style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _bodyTypes.map((b) {
            final isSelected = _selectedBodyType == b;
            return GestureDetector(
              onTap: () => setState(() => _selectedBodyType = b),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? context.palette.primary : context.palette.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? context.palette.primary : context.palette.border,
                  ),
                ),
                child: Text(
                  b,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? context.palette.onAccent
                        : context.palette.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMileage() {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8),
        _buildField(
          'Текущий пробег (км) *',
          _mileageController,
          '0',
          keyboardType: TextInputType.number,
          validationBorderColor: _mileageFieldBorderColor(),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Column(
      key: const ValueKey(4),
      children: [
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: context.palette.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.palette.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (picked != null && mounted) {
                      setState(() => _pickedPhotoPath = picked.path);
                    }
                  },
                  child: Container(
                    width: 120,
                    height: 80,
                    decoration: BoxDecoration(
                      color: context.palette.nestedBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.palette.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _pickedPhotoPath != null
                        ? Image.file(File(_pickedPhotoPath!), fit: BoxFit.cover)
                        : Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 36,
                            color: context.palette.primary,
                          ),
                  ),
                ),
              ),
              if (_pickedPhotoPath != null) ...[
                SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _pickedPhotoPath = null),
                  child: Text('Убрать фото'),
                ),
              ],
              SizedBox(height: 16),
              if (_nicknameController.text.isNotEmpty)
                Text(
                  _nicknameController.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.palette.primary,
                  ),
                ),
              Text(
                '${_useReference ? (_brandOther ? _brandController.text : (_selectedBrand?.name ?? '')) : _brandController.text} ${_useReference ? (_modelOther ? _modelController.text : (_selectedModel?.name ?? '')) : _modelController.text}$_summaryGenerationSuffix',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
                ),
              ),
              SizedBox(height: 12),
              _SummaryRow('Год', _yearController.text),
              if (normalizePlateInput(_plateController.text).isNotEmpty)
                _SummaryRow(
                  'Номер',
                  normalizePlateInput(_plateController.text),
                ),
              if (_selectedEngine != null)
                _SummaryRow('Двигатель', _selectedEngine!),
              if (_selectedTransmission != null)
                _SummaryRow('КПП', _selectedTransmission!),
              if (_selectedDrivetrain != null)
                _SummaryRow('Привод', _selectedDrivetrain!),
              if (_selectedBodyType != null)
                _SummaryRow('Кузов', _selectedBodyType!),
              if (_colorController.text.trim().isNotEmpty)
                _SummaryRow('Цвет', _colorController.text.trim()),
              _SummaryRow('Пробег', '${_mileageController.text} км'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Цвет',
          style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_kColorPresets.length, (i) {
            final p = _kColorPresets[i];
            final sel = _selectedColorPresetIndex == i;
            final dark = ThemeData.estimateBrightnessForColor(p.swatch) ==
                Brightness.dark;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedColorPresetIndex = i;
                  _colorController.text = p.name;
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.swatch,
                  border: Border.all(
                    color: sel
                        ? context.palette.primary
                        : (dark
                            ? Colors.white24
                            : context.palette.border),
                    width: sel ? 2.5 : 1,
                  ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: context.palette.primary.withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 12),
        Text(
          'Свой вариант',
          style: TextStyle(fontSize: 13, color: context.palette.textTertiary),
        ),
        SizedBox(height: 8),
        _buildField(
          'Название цвета (необязательно)',
          _colorController,
          'Например: графит, тёмно-синий',
          onChangedText: _syncColorPresetIndexFromText,
        ),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Color? validationBorderColor,
    void Function(String value)? onChangedText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.palette.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: validationBorderColor ?? context.palette.border,
              width: validationBorderColor != null ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: TextStyle(fontSize: 16, color: context.palette.textPrimary),
            onChanged: (v) {
              onChangedText?.call(v);
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: context.palette.textPlaceholder),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: context.palette.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
