import 'package:flutter/material.dart';
import '../../../../core/theme/client_palette.dart';
/// Полный список марок специализации.
class StoBrandsListScreen extends StatelessWidget {
  const StoBrandsListScreen({super.key, required this.stoName, required this.brands});

  final String stoName;
  final List<String> brands;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final list = List<String>.from(brands)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.cardBg,
        surfaceTintColor: Colors.transparent,
        title: Text('Специализация: $stoName', maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Сервис не ограничивал список марок — работаем с разными авто. Уточните в чате, если сомневаетесь.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.4, color: p.textSecondary),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: list.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: p.border),
              itemBuilder: (context, i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    list[i],
                    style: TextStyle(
                      fontSize: 16,
                      color: p.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
