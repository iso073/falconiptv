abstract final class ExoPlayerBufferSettings {
  static const int minBufferMs = 15000;
  static const int maxBufferMs = 50000;
  static const int bufferForPlaybackMs = 2500;
  static const int bufferForPlaybackAfterRebufferMs = 5000;
  static const int maxReconnectAttempts = 3;
}
