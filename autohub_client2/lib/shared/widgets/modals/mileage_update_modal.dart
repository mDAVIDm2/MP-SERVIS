import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../models/car_model.dart';
import '../common_widgets.dart';

class MileageUpdateModal extends StatefulWidget {
  final Car car;
  final ValueChanged<int> onSave;
  const MileageUpdateModal({super.key, required this.car, required this.onSave});

  static Future<void> show(BuildContext context, Car car, ValueChanged<int> onSave) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MileageUpdateModal(car: car, onSave: onSave),
    );
  }

  @override
  State<MileageUpdateModal> createState() => _MileageUpdateModalState();
}

class _MileageUpdateModalState extends State<MileageUpdateModal> {
  late final TextEditingController _controller;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.car.mileage}');
    _controller.addListener(_validate);
  }

  void _validate() {
    final val = int.tryParse(_controller.text.replaceAll(' ', ''));
    setState(() => _isValid = val != null && val >= widget.car.mileage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Text('Обновить пробег', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
          )),
          const SizedBox(height: 4),
          Text('${widget.car.brand} ${widget.car.model}', style: const TextStyle(
            fontSize: 14, color: AppColors.textSecondary,
          )),
          const SizedBox(height: 8),
          Text('Текущий: ${Formatters.mileage(widget.car.mileage)}', style: const TextStyle(
            fontSize: 14, color: AppColors.textTertiary,
          )),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: AppColors.nestedBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary, fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
                suffixText: 'км',
                suffixStyle: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              autofocus: true,
            ),
          ),
          const SizedBox(height: 24),
          GoldButton(
            text: 'Сохранить',
            onPressed: _isValid ? () {
              final val = int.parse(_controller.text.replaceAll(' ', ''));
              widget.onSave(val);
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
            } : null,
          ),
        ],
      ),
    );
  }
}
