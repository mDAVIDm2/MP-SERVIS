import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/api/reference_api_service.dart';
import '../../../../core/api/car_reference_data.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/russian_license_plate_field.dart';

class AddCarScreen extends ConsumerStatefulWidget {
  const AddCarScreen({super.key});

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

  static const String _kOther = '__other__';
  static const int kMinCarYear = 1950;

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

  int get _maxCarYear => DateTime.now().year;

  bool _yearValid() {
    final s = _yearController.text.trim();
    if (s.length != 4) return false;
    final y = int.tryParse(s);
    if (y == null) return false;
    return y >= kMinCarYear && y <= _maxCarYear;
  }

  bool get _useReference => _brands != null && _brands!.isNotEmpty;

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
  }

  Future<void> _loadBrands() async {
    setState(() => _brandsLoading = true);
    final result = await ref.read(referenceApiServiceProvider).getCarBrands();
    if (!mounted) return;
    final fromApi = result.dataOrNull;
    final useBundled = fromApi == null || fromApi.isEmpty;
    setState(() {
      _brandsLoading = false;
      _brands = useBundled ? CarReferenceData.bundledBrands : fromApi;
      _usingBundledData = useBundled;
    });
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
      setState(() {
        _models = CarReferenceData.modelsForBrand(brandId);
        _modelsLoading = false;
      });
      return;
    }
    final result = await ref
        .read(referenceApiServiceProvider)
        .getCarModels(brandId);
    if (!mounted) return;
    setState(() {
      _modelsLoading = false;
      _models = result.dataOrNull ?? [];
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
      setState(() {
        _generations = list;
        _generationsLoading = false;
      });
      return;
    }
    final result = await ref
        .read(referenceApiServiceProvider)
        .getCarGenerations(_selectedModel!.id);
    if (!mounted) return;
    setState(() {
      _generationsLoading = false;
      _generations = result.dataOrNull ?? [];
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

  Future<void> _handlePrimary() async {
    if (!_canProceed || _saving) return;

    if (_step < _steps.length - 1) {
      setState(() => _step++);
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
            vin: _vinController.text.trim().isEmpty
                ? null
                : _vinController.text.trim(),
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

      var pendingOk = true;
      if (car.hasPendingBrand ||
          car.hasPendingModel ||
          car.hasPendingGeneration) {
        final pendingRes = await ref
            .read(referenceApiServiceProvider)
            .submitPendingCar(
              carId: car.id,
              pendingBrand: car.hasPendingBrand ? car.brand : null,
              pendingModel: car.hasPendingModel ? car.model : null,
              pendingGeneration: car.hasPendingGeneration
                  ? car.generation
                  : null,
            );
        if (pendingRes.errorOrNull != null) {
          pendingOk = false;
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pendingOk
                ? '$brandName $modelName добавлен!'
                : '$brandName $modelName сохранён. Заявка модераторам не дошла — проверьте сеть и попробуйте позже.',
          ),
          backgroundColor: pendingOk
              ? AppColors.success
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          _steps[_step],
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Progress
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: List.generate(
                _steps.length,
                (i) => Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i <= _step
                          ? AppColors.primary
                          : AppColors.nestedBg,
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text('Назад'),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GoldButton(
                    text: _step == _steps.length - 1
                        ? (_saving ? 'Сохранение…' : 'Сохранить')
                        : 'Далее',
                    height: 52,
                    isLoading: _saving && _step == _steps.length - 1,
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
        return const SizedBox();
    }
  }

  Widget _buildBrandModel() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (_brandsLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_useReference) ...[
          _buildDropdown<String>(
            label: 'Марка *',
            value: _brandOther ? _kOther : _selectedBrand?.name,
            items: [
              ..._brands!.map(
                (b) => DropdownMenuItem(value: b.name, child: Text(b.name)),
              ),
              const DropdownMenuItem(
                value: _kOther,
                child: Text('Другое (указать вручную)'),
              ),
            ],
            onChanged: (name) {
              if (name == _kOther) {
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
              } else {
                final brand = _brands!.firstWhere((b) => b.name == name);
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
              }
            },
            hint: 'Выберите марку',
          ),
          if (_brandOther) ...[
            const SizedBox(height: 16),
            _buildField('Марка (вручную) *', _brandController, 'Например: BMW'),
            const SizedBox(height: 16),
            _buildField('Модель (вручную) *', _modelController, 'Например: X5'),
            const SizedBox(height: 16),
            _buildField(
              'Поколение (вручную, необязательно)',
              _customGenerationController,
              'Например: XV70',
            ),
          ],
          const SizedBox(height: 16),
          if (_selectedBrand != null && !_brandOther)
            _modelsLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : _buildDropdown<String>(
                    label: 'Модель *',
                    value: _modelOther ? _kOther : _selectedModel?.name,
                    items: [
                      ...(_models ?? []).map(
                        (m) => DropdownMenuItem(
                          value: m.name,
                          child: Text(m.name),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: _kOther,
                        child: Text('Другое (указать вручную)'),
                      ),
                    ],
                    onChanged: (name) {
                      if (name == _kOther) {
                        setState(() {
                          _modelOther = true;
                          _selectedModel = null;
                          _generationOther = false;
                          _selectedGeneration = null;
                          _generations = null;
                        });
                      } else {
                        final model = _models!.firstWhere(
                          (m) => m.name == name,
                        );
                        setState(() {
                          _modelOther = false;
                          _selectedModel = model;
                          _generationOther = false;
                          _selectedGeneration = null;
                        });
                        _loadGenerations();
                      }
                    },
                    hint: 'Выберите модель',
                  ),
          if (_modelOther) ...[
            const SizedBox(height: 16),
            _buildField('Модель (вручную) *', _modelController, 'Например: X5'),
            if (!_brandOther) ...[
              const SizedBox(height: 16),
              _buildField(
                'Поколение (вручную, необязательно)',
                _customGenerationController,
                'Например: XV70',
              ),
            ],
          ],
          if (_selectedModel != null && !_modelOther) ...[
            if (_generationsLoading)
              const Padding(
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
              const SizedBox(height: 16),
              _buildDropdown<String>(
                label: 'Поколение (необязательно)',
                value: _generationOther ? _kOther : _selectedGeneration?.name,
                items: [
                  ..._generations!.map(
                    (g) => DropdownMenuItem(
                      value: g.name,
                      child: Text(
                        g.yearRange.isNotEmpty
                            ? '${g.name} (${g.yearRange})'
                            : g.name,
                      ),
                    ),
                  ),
                  const DropdownMenuItem(
                    value: _kOther,
                    child: Text('Другое (указать вручную)'),
                  ),
                ],
                onChanged: (name) {
                  if (name == _kOther) {
                    setState(() {
                      _generationOther = true;
                      _selectedGeneration = null;
                    });
                  } else {
                    final gen = _generations!.firstWhere((g) => g.name == name);
                    setState(() {
                      _generationOther = false;
                      _selectedGeneration = gen;
                    });
                  }
                },
                hint: 'Выберите поколение',
              ),
            ],
            if (_generationOther) ...[
              const SizedBox(height: 16),
              _buildField(
                'Поколение (вручную)',
                _customGenerationController,
                'Например: XV70',
              ),
            ],
          ],
        ] else ...[
          _buildField('Марка *', _brandController, 'Например: BMW'),
          const SizedBox(height: 16),
          _buildField('Модель *', _modelController, 'Например: X5'),
        ],
        const SizedBox(height: 16),
        _buildField(
          'Никнейм (необязательно)',
          _nicknameController,
          'Например: Чёрный зверь',
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              hint: Text(
                hint,
                style: const TextStyle(color: AppColors.textPlaceholder),
              ),
              items: items,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildYearVin() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildField(
          'Год выпуска *',
          _yearController,
          '2024',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Год: с $kMinCarYear по $_maxCarYear',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        RussianLicensePlateField(controller: _plateController),
        const SizedBox(height: 16),
        _buildField('VIN (необязательно)', _vinController, '17 символов'),
      ],
    );
  }

  Widget _buildEngine() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Тип двигателя *',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
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
                  color: isSelected ? AppColors.primary : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  e,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF0D0D0D)
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Коробка передач',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
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
                  color: isSelected ? AppColors.primary : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  t,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF0D0D0D)
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _buildField('Цвет', _colorController, 'Например: чёрный, белый'),
        const SizedBox(height: 24),
        const Text(
          'Привод',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
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
                  color: isSelected ? AppColors.primary : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  d,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF0D0D0D)
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Тип кузова *',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
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
                  color: isSelected ? AppColors.primary : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  b,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF0D0D0D)
                        : AppColors.textPrimary,
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
        const SizedBox(height: 8),
        _buildField(
          'Текущий пробег (км) *',
          _mileageController,
          '0',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Column(
      key: const ValueKey(4),
      children: [
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.nestedBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              if (_nicknameController.text.isNotEmpty)
                Text(
                  _nicknameController.text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              Text(
                '${_useReference ? (_brandOther ? _brandController.text : (_selectedBrand?.name ?? '')) : _brandController.text} ${_useReference ? (_modelOther ? _modelController.text : (_selectedModel?.name ?? '')) : _modelController.text}$_summaryGenerationSuffix',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
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

  Widget _buildField(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textPlaceholder),
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
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
