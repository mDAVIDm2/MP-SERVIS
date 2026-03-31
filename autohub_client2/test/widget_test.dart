import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autohub_client/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AutoHubApp()),
    );
    // Проверяем что splash-экран отображается
    expect(find.text('AutoHub'), findsOneWidget);
  });
}
