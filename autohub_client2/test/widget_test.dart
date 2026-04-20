import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autohub_client/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MpServisApp()),
    );
    // Проверяем что splash-экран отображается
    expect(find.text('MP-Servis'), findsOneWidget);
    // Дождаться таймера в MpServisApp (1.5 s), иначе тест падает на pending timers
    await tester.pump(const Duration(milliseconds: 1600));
  });
}
