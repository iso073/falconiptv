import 'package:falconiptv/core/widgets/neon_focus_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpCard(
  WidgetTester tester, {
  required VoidCallback onActivate,
  required VoidCallback onLongPress,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NeonFocusCard(
          autofocus: true,
          onActivate: onActivate,
          onLongPress: onLongPress,
          child: const Text('Profil'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kısa OK basışı kartı aktive eder', (WidgetTester tester) async {
    int activated = 0;
    int longPressed = 0;
    await _pumpCard(
      tester,
      onActivate: () => activated++,
      onLongPress: () => longPressed++,
    );

    await simulateKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 120));
    await simulateKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 300));

    expect(activated, 1);
    expect(longPressed, 0);
  });

  testWidgets('uzun OK basışı yalnızca uzun basmayı tetikler', (WidgetTester tester) async {
    int activated = 0;
    int longPressed = 0;
    await _pumpCard(
      tester,
      onActivate: () => activated++,
      onLongPress: () => longPressed++,
    );

    await simulateKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 700));
    await simulateKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 300));

    expect(longPressed, 1);
    expect(activated, 0);
  });

  testWidgets('tuş tekrarı down/up çiftleri olarak gelse de uzun basma çalışır',
      (WidgetTester tester) async {
    int activated = 0;
    int longPressed = 0;
    await _pumpCard(
      tester,
      onActivate: () => activated++,
      onLongPress: () => longPressed++,
    );

    for (int i = 0; i < 8; i++) {
      await simulateKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 80));
      await simulateKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(milliseconds: 300));

    expect(longPressed, 1);
    expect(activated, 0);
  });
}
