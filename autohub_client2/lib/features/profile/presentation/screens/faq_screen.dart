import 'package:flutter/material.dart';
import '../../../../core/theme/client_palette.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _faqItems = [
    _FaqItem(q: 'Как записаться на сервис?', a: 'Найдите нужный автосервис через вкладку "Поиск", выберите услуги и удобное время. После подтверждения вы получите уведомление.'),
    _FaqItem(q: 'Как добавить автомобиль?', a: 'Перейдите в "Гараж" и нажмите "+". Заполните данные авто по шагам: марка, модель, год, двигатель и пробег.'),
    _FaqItem(q: 'Что такое согласование?', a: 'Если сервис обнаружит дополнительные работы, вам придёт запрос на согласование в чате. Вы можете принять или отклонить каждую позицию.'),
    _FaqItem(q: 'Как отменить запись?', a: 'Откройте заказ и нажмите "Отменить запись". Отмена возможна не позднее чем за 2 часа до визита.'),
    _FaqItem(q: 'Как оставить отзыв?', a: 'После завершения заказа нажмите "Оставить отзыв" на экране деталей заказа. Оцените от 1 до 5 звёзд и напишите комментарий.'),
    _FaqItem(q: 'Как работают напоминания о ТО?', a: 'MP-Servis отслеживает пробег и сроки обслуживания. При приближении рекомендованных интервалов вы получите уведомление.'),
    _FaqItem(q: 'Безопасно ли хранить данные?', a: 'Все данные зашифрованы и хранятся на защищённых серверах. Мы не передаём информацию третьим лицам.'),
    _FaqItem(q: 'Как связаться с поддержкой?', a: 'Перейдите в Профиль → Поддержка → "Написать в поддержку". Мы ответим в течение 24 часов.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        title: Text('Частые вопросы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: _faqItems.length,
        separatorBuilder: (_, __) => SizedBox(height: 8),
        itemBuilder: (_, i) => _FaqCard(item: _faqItems[i]),
      ),
    );
  }
}

class _FaqItem {
  final String q, a;
  const _FaqItem({required this.q, required this.a});
}

class _FaqCard extends StatefulWidget {
  final _FaqItem item;
  const _FaqCard({super.key, required this.item});

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.palette.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _expanded ? context.palette.primary.withValues(alpha: 0.3) : context.palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(widget.item.q, style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: context.palette.textPrimary,
                ))),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(Icons.expand_more_rounded, color: context.palette.textTertiary),
                ),
              ],
            ),
            if (_expanded) ...[
              SizedBox(height: 12),
              Text(widget.item.a, style: TextStyle(
                fontSize: 14, color: context.palette.textSecondary, height: 1.5,
              )),
            ],
          ],
        ),
      ),
    );
  }
}
