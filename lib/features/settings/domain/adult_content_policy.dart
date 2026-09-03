/// Detects adult categories coming from Xtream or M3U providers, which are
/// named inconsistently across servers.
abstract final class AdultContentPolicy {
  static const List<String> _markers = <String>[
    'adult',
    'xxx',
    'porn',
    'erotik',
    'erotic',
    'sex',
    'yetiskin',
    '18+',
    '+18',
    'for adults',
  ];

  static String _normalize(String value) {
    final StringBuffer buffer = StringBuffer();
    for (final int rune in value.runes) {
      final String char = String.fromCharCode(rune);
      buffer.write(switch (char) {
        'İ' || 'I' || 'ı' || 'i' => 'i',
        'Ü' || 'ü' => 'u',
        'Ö' || 'ö' => 'o',
        'Ş' || 'ş' => 's',
        'Ç' || 'ç' => 'c',
        'Ğ' || 'ğ' => 'g',
        _ => char.toLowerCase(),
      });
    }
    return buffer.toString().trim();
  }

  static bool isAdult(String category) {
    final String normalized = _normalize(category);
    return _markers.any(normalized.contains);
  }

  static bool isAdultContent({
    required String category,
    String title = '',
    String subtitle = '',
  }) {
    return isAdult(category) || isAdult(title) || isAdult(subtitle);
  }
}
