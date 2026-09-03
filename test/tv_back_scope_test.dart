import 'package:falconiptv/core/widgets/tv_back_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pressBack(WidgetTester tester) async {
  await simulateKeyDownEvent(LogicalKeyboardKey.escape);
  await simulateKeyUpEvent(LogicalKeyboardKey.escape);
  await tester.pump(const Duration(milliseconds: 20));
}

// The guard compares wall-clock time, so the test has to wait for real.
Future<void> _waitOutGuard(WidgetTester tester) {
  return tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
}

void main() {
  setUp(TvBackScope.resetBackGuard);

  testWidgets('tek geri basışı hem tuş hem pop kanalından gelse bir kez işlenir',
      (WidgetTester tester) async {
    int backCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: TvBackScope(
          onBack: () async => backCount++,
          child: const Scaffold(body: Text('Oynatıcı')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _pressBack(tester);

    // Android also routes the same press through the activity back channel.
    final NavigatorState navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pump(const Duration(milliseconds: 20));

    expect(backCount, 1);

    await _waitOutGuard(tester);
    await _pressBack(tester);

    expect(backCount, 2);
  });

  testWidgets('yinelenen geri olayı ikinci bir sayfaya sızmaz', (WidgetTester tester) async {
    int playerBack = 0;
    int catalogBack = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TvBackScope(
                onBack: () async => catalogBack++,
                child: const Text('Katalog'),
              ),
              TvBackScope(
                onBack: () async => playerBack++,
                child: const Text('Oynatıcı'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _pressBack(tester);

    expect(playerBack + catalogBack, 1);
  });
}
