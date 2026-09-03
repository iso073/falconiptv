class MediaTrack {
  const MediaTrack({required this.id, required this.label, this.url, this.kind = MediaTrackKind.audio});

  final String id;
  final String label;
  final String? url;
  final MediaTrackKind kind;
}

enum MediaTrackKind { audio, subtitle }

abstract final class HlsTrackParser {
  static final RegExp _media = RegExp(
    r'#EXT-X-MEDIA:([^\r\n]+)',
    caseSensitive: false,
  );
  static final RegExp _attr = RegExp(r'([A-Z0-9-]+)=("([^"]*)"|[^,]+)', caseSensitive: false);

  static List<MediaTrack> parse(String source) {
    final List<MediaTrack> tracks = <MediaTrack>[];
    int index = 0;
    for (final RegExpMatch match in _media.allMatches(source)) {
      final Map<String, String> attrs = _attributes(match.group(1) ?? '');
      final String type = (attrs['TYPE'] ?? '').toUpperCase();
      if (type != 'AUDIO' && type != 'SUBTITLES') {
        continue;
      }
      final String label = attrs['NAME'] ?? attrs['LANGUAGE'] ?? (type == 'AUDIO' ? 'Ses' : 'Altyazı');
      tracks.add(
        MediaTrack(
          id: '${type.toLowerCase()}_${index++}',
          label: label,
          url: attrs['URI'],
          kind: type == 'AUDIO' ? MediaTrackKind.audio : MediaTrackKind.subtitle,
        ),
      );
    }
    return tracks;
  }

  static Map<String, String> _attributes(String source) {
    final Map<String, String> attrs = <String, String>{};
    for (final RegExpMatch match in _attr.allMatches(source)) {
      final String key = match.group(1) ?? '';
      final String quoted = match.group(3) ?? '';
      final String raw = match.group(2) ?? '';
      attrs[key] = quoted.isNotEmpty ? quoted : raw;
    }
    return attrs;
  }
}
