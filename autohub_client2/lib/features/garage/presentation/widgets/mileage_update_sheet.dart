import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../shared/widgets/common_widgets.dart';

class MileageUpdateSheet extends StatefulWidget {
  final Car car;
  final ValueChanged<int> onSave;
  const MileageUpdateSheet({super.key, required this.car, required this.onSave});

  static Future<void> show(BuildContext context, Car car, ValueChanged<int> onSave) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MileageUpdateSheet(car: car, onSave: onSave),
    );
  }

  @override
  State<MileageUpdateSheet> createState() => _MileageUpdateSheetState();
}

class _MileageUpdateSheetState extends State<MileageUpdateSheet> {
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
              color: context.palette.textTertiary, borderRadius: BorderRadius.circular(2)),
          ),
          SizedBox(height: 20),
          Text('Обновить пробег', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: context.palette.textPrimary,
          )),
          SizedBox(height: 4),
          Text('${widget.car.brand} ${widget.car.model}', style: TextStyle(
            fontSize: 14, color: context.palette.textSecondary,
          )),
          SizedBox(height: 8),
          Text('Текущий: ${Formatters.mileage(widget.car.mileage)}', style: TextStyle(
            fontSize: 14, color: context.palette.textTertiary,
          )),
          SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: context.palette.nestedBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.palette.border),
            ),
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w700,
                color: context.palette.textPrimary, fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
                suffixText: 'км  ',
                suffixStyle: TextStyle(fontSize: 16, color: context.palette.textSecondary),
              ),
              autofocus: true,
            ),
          ),
          SizedBox(height: 24),
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
