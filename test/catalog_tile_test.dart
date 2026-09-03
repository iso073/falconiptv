import 'package:falconiptv/features/catalog/presentation/pages/catalog_browser_page.dart';
import 'package:falconiptv/features/iptv/data/models/playable_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CatalogTile uzun kanal adında taşma üretmez', (WidgetTester tester) async {
    const PlayableItem item = PlayableItem(
      id: '1',
      title: '4U TV (720p) Ekstra Uzun Kanal Adı Örneği',
      subtitle: 'Entertainment',
      category: 'Entertainment',
      streamUrl: 'http://server.invalid/live/1.m3u8',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 149,
              height: 149,
              child: CatalogTile(
                item: item,
                accent: Colors.cyan,
                icon: Icons.live_tv_rounded,
                onActivate: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
