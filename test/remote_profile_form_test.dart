import 'package:flutter_test/flutter_test.dart';

import 'package:falconiptv/features/profile/data/remote_profile_form_html.dart';

void main() {
  test('telefon formu Xtream ve M3U alanlarını içerir', () {
    final String html = RemoteProfileFormHtml.page();
    expect(html.contains('Xtream Codes'), isTrue);
    expect(html.contains('M3U'), isTrue);
    expect(html.contains('/api/add'), isTrue);
  });
}
