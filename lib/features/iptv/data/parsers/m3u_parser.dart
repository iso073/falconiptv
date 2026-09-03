import 'dart:convert';

import '../models/playable_item.dart';

abstract final class M3uParser {
  static final RegExp _tvgLogo = RegExp(r'tvg-logo="([^"]*)"', caseSensitive: false);
  static final RegExp _groupTitle = RegExp(r'group-title="([^"]*)"', caseSensitive: false);
  static final RegExp _tvgName = RegExp(r'tvg-name="([^"]*)"', caseSensitive: false);

  static List<PlayableItem> parse(String source) {
    final List<PlayableItem> items = <PlayableItem>[];
    String? pendingInfo;
    int index = 0;

    for (final String raw in const LineSplitter().convert(source)) {
      final String line = raw.trim();
      if (line.isEmpty) {
        continue;
      }
      if (line.startsWith('#EXTINF')) {
        pendingInfo = line;
        continue;
      }
      if (line.startsWith('#')) {
        continue;
      }
      if (pendingInfo == null || !_isStreamUrl(line)) {
        continue;
      }

      final String category = _attribute(_groupTitle, pendingInfo) ?? 'Diğer';
      final String? logo = _attribute(_tvgLogo, pendingInfo);
      final String title = _channelName(pendingInfo);
      items.add(
        PlayableItem(
          id: '${index++}',
          title: title,
          subtitle: category,
          category: category,
          streamUrl: line,
          logoUrl: logo,
        ),
      );
      pendingInfo = null;
    }
    return items;
  }

  static List<String> categoriesOf(List<PlayableItem> items) {
    final List<String> categories = <String>[];
    for (final PlayableItem item in items) {
      if (!categories.contains(item.category)) {
        categories.add(item.category);
      }
    }
    categories.sort();
    return <String>['Tümü', ...categories];
  }

  static bool _isStreamUrl(String line) {
    final String lower = line.toLowerCase();
    return lower.startsWith('http') || lower.startsWith('rtmp') || lower.startsWith('rtsp');
  }

  static String? _attribute(RegExp pattern, String source) {
    final String? value = pattern.firstMatch(source)?.group(1)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static String _channelName(String extinf) {
    final int comma = extinf.lastIndexOf(',');
    if (comma != -1 && comma < extinf.length - 1) {
      final String afterComma = extinf.substring(comma + 1).trim();
      if (afterComma.isNotEmpty) {
        return afterComma;
      }
    }
    return _attribute(_tvgName, extinf) ?? 'Adsız Kanal';
  }
}
