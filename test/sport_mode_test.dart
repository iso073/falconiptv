import 'package:falconiptv/features/player/data/exoplayer_buffer_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('spor modu kapalıyken mevcut tampon kullanılır', () {
    final ExoPlayerBufferSettings settings = ExoPlayerBufferSettings.current(sportMode: false);
    expect(settings.minBufferMs, 15000);
    expect(settings.bufferForPlaybackMs, 2500);
    expect(settings.maxReconnectAttempts, 3);
  });

  test('spor modu 30 saniye hedef tampon kullanır', () {
    final ExoPlayerBufferSettings settings = ExoPlayerBufferSettings.current(sportMode: true);
    expect(settings.minBufferMs, 30000);
    expect(settings.bufferForPlaybackMs, 8000);
    expect(settings.maxReconnectAttempts, 5);
    expect(settings.readyWait, const Duration(seconds: 12));
    expect(settings.minHold, const Duration(seconds: 8));
  });
}
