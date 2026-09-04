class ExoPlayerBufferSettings {
  const ExoPlayerBufferSettings({
    required this.minBufferMs,
    required this.maxBufferMs,
    required this.bufferForPlaybackMs,
    required this.bufferForPlaybackAfterRebufferMs,
    required this.maxReconnectAttempts,
    required this.readyWait,
    this.minHold = Duration.zero,
  });

  final int minBufferMs;
  final int maxBufferMs;
  final int bufferForPlaybackMs;
  final int bufferForPlaybackAfterRebufferMs;
  final int maxReconnectAttempts;
  final Duration readyWait;
  final Duration minHold;

  static const ExoPlayerBufferSettings standard = ExoPlayerBufferSettings(
    minBufferMs: 15000,
    maxBufferMs: 50000,
    bufferForPlaybackMs: 2000,
    bufferForPlaybackAfterRebufferMs: 5000,
    maxReconnectAttempts: 3,
    readyWait: Duration(seconds: 2),
    minHold: Duration(seconds: 2),
  );

  /// Hedef depo 30 sn; açılış 8–12 sn bekler, 30 sn kilitlemez.
  static const ExoPlayerBufferSettings sport = ExoPlayerBufferSettings(
    minBufferMs: 30000,
    maxBufferMs: 70000,
    bufferForPlaybackMs: 8000,
    bufferForPlaybackAfterRebufferMs: 12000,
    maxReconnectAttempts: 5,
    readyWait: Duration(seconds: 12),
    minHold: Duration(seconds: 8),
  );

  static ExoPlayerBufferSettings current({required bool sportMode}) {
    return sportMode ? sport : standard;
  }
}
