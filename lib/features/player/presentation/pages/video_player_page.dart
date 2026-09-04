import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/network/iptv_dio_client.dart';
import '../../../../core/playback/playback_keep_awake.dart';
import '../../../../core/services/tv_toast_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/exit_confirm_dialog.dart';
import '../../../../core/widgets/neon_focus_card.dart';
import '../../../../core/widgets/tv_back_scope.dart';
import '../../../iptv/data/models/playable_item.dart';
import '../../../iptv/data/models/series_details.dart';
import '../../../iptv/data/repositories/iptv_catalog_repository.dart';
import '../../../library/data/watch_progress_repository.dart';
import '../../../library/presentation/playback_launcher.dart';
import '../../data/exoplayer_buffer_settings.dart';
import '../../data/hls_track_parser.dart';
import '../../domain/player_aspect_ratio.dart';
import '../../../settings/data/sport_mode_repository.dart';

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.playlist,
    this.initialIndex = 0,
    this.resumeFrom,
  });

  final List<PlayableItem> playlist;
  final int initialIndex;
  final Duration? resumeFrom;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> with WidgetsBindingObserver {
  late int _index;
  VideoPlayerController? _controller;
  bool _osdVisible = true;
  bool _loading = true;
  String? _error;
  PlayerAspectRatio _aspect = PlayerAspectRatio.widescreen;
  int _reconnectAttempt = 0;
  bool _reconnecting = false;
  Timer? _osdTimer;
  Timer? _progressTimer;
  Timer? _seekTimer;
  Timer? _okHoldTimer;
  Timer? _okReleaseTimer;
  bool _okPressing = false;
  bool _okLongPressFired = false;
  Duration? _pendingSeek;
  bool _channelListVisible = false;
  bool _tracksVisible = false;
  List<MediaTrack> _audioTracks = const <MediaTrack>[];
  List<MediaTrack> _subtitleTracks = const <MediaTrack>[];
  String _selectedAudio = 'Varsayılan';
  String _selectedSubtitle = 'Kapalı';
  String? _captionText;
  bool _resumeApplied = false;
  bool _stopped = false;
  bool _autoAdvancing = false;
  bool _endHandled = false;
  VideoPlayerController? _opening;
  final Set<VideoPlayerController> _released = <VideoPlayerController>{};
  final FocusNode _focusNode = FocusNode();

  PlayableItem get _current => widget.playlist[_index];

  bool get _isOnDemand => _current.kind != PlayableKind.live;

  bool get _isSeriesEpisode =>
      _current.kind == PlayableKind.series && _current.streamUrl.isNotEmpty;

  static const MethodChannel _exoChannel = MethodChannel('falconiptv/exoplayer');

  ExoPlayerBufferSettings get _buffer {
    final bool sportOn = context.read<SportModeRepository>().enabled;
    return ExoPlayerBufferSettings.current(sportMode: sportOn);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(PlaybackKeepAwake.enable());
    if (widget.playlist.isEmpty) {
      _index = 0;
      _loading = false;
      _error = 'Oynatılabilir yayın bulunamadı.';
      return;
    }
    _index = widget.initialIndex.clamp(0, widget.playlist.length - 1);
    _openCurrent();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(PlaybackKeepAwake.enable());
    }
  }

  @override
  void dispose() {
    _stopped = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(PlaybackKeepAwake.disable());
    _osdTimer?.cancel();
    _progressTimer?.cancel();
    _seekTimer?.cancel();
    _resetOkPress();
    final VideoPlayerController? current = _controller;
    final VideoPlayerController? opening = _opening;
    _controller = null;
    _opening = null;
    _abandonController(current);
    if (!identical(opening, current)) {
      _abandonController(opening);
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _abandonController(VideoPlayerController? controller) {
    if (controller == null) {
      return;
    }
    controller.removeListener(_onPlayerUpdate);
    unawaited(_releaseController(controller));
  }

  Future<void> _releaseController(VideoPlayerController? controller) async {
    if (controller == null || !_released.add(controller)) {
      return;
    }
    controller.removeListener(_onPlayerUpdate);
    try {
      await controller.setVolume(0);
    } catch (_) {}
    try {
      await controller.pause();
    } catch (_) {}
    try {
      await controller.dispose();
    } catch (_) {}
  }

  Future<void> _stopPlayback() async {
    _stopped = true;
    _reconnecting = false;
    _progressTimer?.cancel();
    _osdTimer?.cancel();
    _seekTimer?.cancel();
    unawaited(PlaybackKeepAwake.disable());
    final VideoPlayerController? current = _controller;
    final VideoPlayerController? opening = _opening;
    _controller = null;
    _opening = null;
    await _releaseController(current);
    if (!identical(opening, current)) {
      await _releaseController(opening);
    }
  }

  void _scheduleOsdHide() {
    _osdTimer?.cancel();
    _osdTimer = Timer(const Duration(seconds: 5), () {
      final VideoPlayerController? controller = _controller;
      final bool paused = controller != null &&
          controller.value.isInitialized &&
          !controller.value.isPlaying;
      if (mounted && !paused) {
        setState(() => _osdVisible = false);
      }
    });
  }

  Future<void> _openCurrent({bool isReconnect = false}) async {
    if (_stopped) {
      return;
    }
    _endHandled = false;
    _progressTimer?.cancel();
    final VideoPlayerController? previous = _controller;
    previous?.removeListener(_onPlayerUpdate);
    setState(() {
      _loading = true;
      _error = null;
      if (!isReconnect) {
        _reconnectAttempt = 0;
      }
    });

    final ExoPlayerBufferSettings buffer = _buffer;
    try {
      await _exoChannel.invokeMethod<void>(
        'setSportMode',
        context.read<SportModeRepository>().enabled,
      );
    } catch (_) {}

    final Uri uri = Uri.parse(_current.streamUrl);
    final VideoPlayerController next = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: <String, String>{
        'User-Agent': IptvDioClient.userAgent,
      },
      formatHint: _current.streamUrl.contains('.m3u8') ? VideoFormat.hls : VideoFormat.other,
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      ),
    );
    _opening = next;

    try {
      await next.initialize();
      if (_stopped || !mounted) {
        await _releaseController(next);
        return;
      }
      if (buffer.minHold > Duration.zero) {
        await _waitForBuffer(next, buffer);
        if (_stopped || !mounted) {
          await _releaseController(next);
          return;
        }
      }
      next.addListener(_onPlayerUpdate);
      await next.play();
      if (_stopped || !mounted) {
        await _releaseController(next);
        return;
      }
      if (!isReconnect && !_resumeApplied && widget.resumeFrom != null) {
        await next.seekTo(widget.resumeFrom!);
        _resumeApplied = true;
      }
      if (_stopped || !mounted) {
        await _releaseController(next);
        return;
      }
      setState(() {
        _controller = next;
        _opening = null;
        _loading = false;
        _error = null;
        _osdVisible = true;
        _captionText = null;
        _selectedAudio = 'Varsayılan';
        _selectedSubtitle = 'Kapalı';
      });
      if (!identical(previous, next)) {
        unawaited(_releaseController(previous));
      }
      _scheduleOsdHide();
      unawaited(_loadTracks());
      _progressTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        _saveProgress();
        if (mounted) {
          setState(() {});
        }
      });
    } catch (_) {
      if (identical(_opening, next)) {
        _opening = null;
      }
      await _releaseController(next);
      if (!_stopped) {
        await _handlePlaybackFailure();
      }
    }
  }

  Future<void> _waitForBuffer(
    VideoPlayerController controller,
    ExoPlayerBufferSettings buffer,
  ) async {
    final Duration target = Duration(milliseconds: buffer.bufferForPlaybackMs);
    final DateTime started = DateTime.now();
    final DateTime deadline = started.add(buffer.readyWait);
    while (DateTime.now().isBefore(deadline)) {
      if (_stopped || !mounted) {
        return;
      }
      if (DateTime.now().difference(started) >= buffer.minHold) {
        final List<DurationRange> ranges = controller.value.buffered;
        if (ranges.isNotEmpty && ranges.last.end >= target) {
          return;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  void _onPlayerUpdate() {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !mounted) {
      return;
    }
    final String caption = controller.value.caption.text;
    if (caption != _captionText) {
      setState(() => _captionText = caption);
    }
    if (controller.value.hasError) {
      _handlePlaybackFailure();
    }
    if (_isSeriesEpisode && _shouldAdvanceEpisode(controller.value)) {
      unawaited(_playNextEpisode());
    }
  }

  bool _shouldAdvanceEpisode(VideoPlayerValue value) {
    if (_autoAdvancing || _endHandled || _stopped || _loading || !value.isInitialized || value.hasError) {
      return false;
    }
    if (value.duration.inSeconds < 3) {
      return false;
    }
    if (value.isCompleted) {
      return true;
    }
    return value.position >= value.duration - const Duration(milliseconds: 800);
  }

  Future<void> _playNextEpisode() async {
    if (_autoAdvancing || _stopped) {
      return;
    }
    if (_index + 1 >= widget.playlist.length) {
      _endHandled = true;
      if (mounted) {
        TvToastService.show(
          context,
          'Son bölüm. İzleme tamamlandı.',
          type: TvToastType.info,
        );
      }
      return;
    }
    _autoAdvancing = true;
    _saveProgress();
    _index += 1;
    if (mounted) {
      TvToastService.show(
        context,
        'Sonraki bölüm: ${_current.title}',
        type: TvToastType.success,
      );
    }
    try {
      await _openCurrent();
    } finally {
      _autoAdvancing = false;
    }
  }

  void _saveProgress() {
    if (!_isOnDemand) {
      return;
    }
    final VideoPlayerController? controller = _controller;
    final String? profileId = PlaybackLauncher.profileOf(context)?.id;
    if (controller == null || !controller.value.isInitialized || profileId == null) {
      return;
    }
    context.read<WatchProgressRepository>().save(
          profileId: profileId,
          item: _current,
          position: controller.value.position,
          duration: controller.value.duration,
        );
  }

  Future<void> _loadTracks() async {
    final List<MediaTrack> audio = <MediaTrack>[
      const MediaTrack(id: 'audio_default', label: 'Varsayılan'),
    ];
    final List<MediaTrack> subs = <MediaTrack>[
      const MediaTrack(id: 'sub_off', label: 'Kapalı', kind: MediaTrackKind.subtitle),
    ];
    final IptvCatalogRepository catalog = context.read<IptvCatalogRepository>();
    final profile = PlaybackLauncher.profileOf(context);
    final Dio dio = IptvDioClient.create();
    try {
      if (_current.streamUrl.toLowerCase().contains('.m3u8')) {
        final Response<String> response = await dio.get<String>(
          _current.streamUrl,
          options: Options(responseType: ResponseType.plain, receiveTimeout: const Duration(seconds: 12)),
        );
        final List<MediaTrack> parsed = HlsTrackParser.parse(response.data ?? '');
        audio.addAll(parsed.where((MediaTrack track) => track.kind == MediaTrackKind.audio));
        subs.addAll(parsed.where((MediaTrack track) => track.kind == MediaTrackKind.subtitle));
      }
      final List<StreamSubtitle> remote = await catalog.loadSubtitles(profile, _current);
      for (final StreamSubtitle track in remote) {
        subs.add(
          MediaTrack(
            id: 'xtream_${track.url.hashCode}',
            label: track.label,
            url: track.url,
            kind: MediaTrackKind.subtitle,
          ),
        );
      }
    } catch (_) {
    } finally {
      dio.close();
    }
    if (mounted) {
      setState(() {
        _audioTracks = audio;
        _subtitleTracks = subs;
      });
    }
  }

  Future<void> _selectAudio(MediaTrack track) async {
    setState(() {
      _selectedAudio = track.label;
      _tracksVisible = false;
    });
    _focusNode.requestFocus();
    _showOsd();
  }

  Future<void> _selectSubtitle(MediaTrack track) async {
    final VideoPlayerController? controller = _controller;
    if (controller == null) {
      return;
    }
    if (track.url == null || track.id == 'sub_off') {
      await controller.setClosedCaptionFile(null);
      setState(() {
        _selectedSubtitle = 'Kapalı';
        _captionText = null;
        _tracksVisible = false;
      });
      _focusNode.requestFocus();
      return;
    }
    try {
      final Dio dio = IptvDioClient.create();
      final Response<String> response = await dio.get<String>(
        track.url!,
        options: Options(responseType: ResponseType.plain, receiveTimeout: const Duration(seconds: 15)),
      );
      dio.close();
      final String body = response.data ?? '';
      final ClosedCaptionFile file = body.contains('WEBVTT') || track.url!.toLowerCase().contains('.vtt')
          ? WebVTTCaptionFile(body)
          : SubRipCaptionFile(body);
      await controller.setClosedCaptionFile(Future<ClosedCaptionFile>.value(file));
      setState(() {
        _selectedSubtitle = track.label;
        _tracksVisible = false;
      });
    } catch (_) {
      setState(() => _tracksVisible = false);
    }
    _focusNode.requestFocus();
    _showOsd();
  }

  void _openTracks() {
    _resetOkPress();
    _osdTimer?.cancel();
    setState(() {
      _tracksVisible = true;
      _channelListVisible = false;
      _osdVisible = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.unfocus();
      }
    });
  }

  void _closeTracks() {
    setState(() => _tracksVisible = false);
    _focusNode.requestFocus();
    _showOsd();
  }

  Future<void> _handlePlaybackFailure() async {
    if (_stopped || _reconnecting) {
      return;
    }
    if (_reconnectAttempt >= _buffer.maxReconnectAttempts) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Yayın bağlantısı koptu. Lütfen daha sonra yeniden deneyiniz.';
        });
      }
      return;
    }
    _reconnecting = true;
    _reconnectAttempt += 1;
    if (mounted) {
      setState(() => _loading = true);
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!_stopped && mounted) {
      await _openCurrent(isReconnect: true);
    }
    _reconnecting = false;
  }

  Future<void> _zap(int delta) async {
    _saveProgress();
    if (widget.playlist.isEmpty) {
      return;
    }
    final int nextIndex = (_index + delta) % widget.playlist.length;
    _index = nextIndex < 0 ? widget.playlist.length - 1 : nextIndex;
    await _openCurrent();
  }

  void _openChannelList() {
    if (widget.playlist.length < 2) {
      return;
    }
    _resetOkPress();
    _osdTimer?.cancel();
    setState(() {
      _channelListVisible = true;
      _osdVisible = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.unfocus();
      }
    });
  }

  void _closeChannelList() {
    setState(() => _channelListVisible = false);
    _focusNode.requestFocus();
    setState(() => _osdVisible = true);
    _scheduleOsdHide();
  }

  Future<void> _selectChannel(int index) async {
    setState(() => _channelListVisible = false);
    _focusNode.requestFocus();
    if (index == _index) {
      _osdVisible = true;
      _scheduleOsdHide();
      return;
    }
    _index = index;
    await _openCurrent();
  }

  void _showOsd() {
    if (!_osdVisible) {
      setState(() => _osdVisible = true);
    }
    _scheduleOsdHide();
  }

  void _cycleAspect(bool forward) {
    setState(() => _aspect = forward ? _aspect.next : _aspect.previous);
    if (!_tracksVisible) {
      _showOsd();
    }
  }

  Duration get _displayedPosition =>
      _pendingSeek ?? _controller?.value.position ?? Duration.zero;

  /// Batches rapid arrow presses into a single seek so holding the key scrubs
  /// smoothly instead of firing one request per repeat.
  void _seekBy(Duration delta) {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final Duration duration = controller.value.duration;
    if (duration <= Duration.zero) {
      return;
    }

    final Duration base = _pendingSeek ?? controller.value.position;
    final int targetMs = (base + delta).inMilliseconds.clamp(0, duration.inMilliseconds);
    setState(() => _pendingSeek = Duration(milliseconds: targetMs));
    _showOsd();

    _seekTimer?.cancel();
    _seekTimer = Timer(const Duration(milliseconds: 350), () async {
      final Duration? target = _pendingSeek;
      if (target == null || !mounted) {
        return;
      }
      await controller.seekTo(target);
      if (!controller.value.isPlaying) {
        await controller.play();
      }
      if (mounted) {
        setState(() => _pendingSeek = null);
      }
    });
  }

  Future<void> _togglePlayPause() async {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) {
      setState(() {});
      _showOsd();
    }
  }

  static const Duration _okLongPressThreshold = Duration(milliseconds: 500);
  static const Duration _okReleaseGrace = Duration(milliseconds: 180);

  bool _isOkKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
  }

  bool _isTracksKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.contextMenu ||
        key == LogicalKeyboardKey.info ||
        key == LogicalKeyboardKey.help;
  }

  void _resetOkPress() {
    _okHoldTimer?.cancel();
    _okHoldTimer = null;
    _okReleaseTimer?.cancel();
    _okReleaseTimer = null;
    _okPressing = false;
    _okLongPressFired = false;
  }

  void _onOkDown() {
    _okReleaseTimer?.cancel();
    _okReleaseTimer = null;
    if (_okPressing) {
      return;
    }
    _okPressing = true;
    _okLongPressFired = false;
    _okHoldTimer?.cancel();
    _okHoldTimer = Timer(_okLongPressThreshold, () {
      if (!_okPressing || _okLongPressFired) {
        return;
      }
      _okLongPressFired = true;
      _openTracks();
    });
  }

  void _onOkUp() {
    if (!_okPressing) {
      return;
    }
    _okReleaseTimer?.cancel();
    _okReleaseTimer = Timer(_okReleaseGrace, () {
      final bool wasLongPress = _okLongPressFired;
      _resetOkPress();
      if (wasLongPress) {
        return;
      }
      if (_isOnDemand) {
        _togglePlayPause();
      } else {
        _openChannelList();
      }
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_channelListVisible || _tracksVisible) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;

    if (_isOkKey(key)) {
      if (event is KeyDownEvent) {
        _onOkDown();
      } else if (event is KeyUpEvent) {
        _onOkUp();
      }
      return KeyEventResult.handled;
    }

    final bool isPress = event is KeyDownEvent || event is KeyRepeatEvent;
    if (!isPress) {
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause) {
      _togglePlayPause();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaFastForward ||
        key == LogicalKeyboardKey.mediaTrackNext) {
      _seekBy(const Duration(seconds: 30));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaRewind ||
        key == LogicalKeyboardKey.mediaTrackPrevious) {
      _seekBy(const Duration(seconds: -30));
      return KeyEventResult.handled;
    }
    if (_isTracksKey(key)) {
      _openTracks();
      return KeyEventResult.handled;
    }

    if (_isOnDemand) {
      if (key == LogicalKeyboardKey.arrowRight) {
        _seekBy(const Duration(seconds: 10));
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        _seekBy(const Duration(seconds: -10));
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _seekBy(const Duration(minutes: 1));
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _seekBy(const Duration(minutes: -1));
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      _zap(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _zap(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _cycleAspect(false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _cycleAspect(true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static String _formatDuration(Duration value) {
    final int totalSeconds = value.inSeconds;
    final String minutes = (totalSeconds ~/ 60 % 60).toString().padLeft(2, '0');
    final String seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    final int hours = totalSeconds ~/ 3600;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Widget _buildVideo(VideoPlayerController controller) {
    final Size size = controller.value.size;
    final Widget player = size.width > 0 && size.height > 0
        ? SizedBox(width: size.width, height: size.height, child: VideoPlayer(controller))
        : VideoPlayer(controller);

    return switch (_aspect) {
      PlayerAspectRatio.widescreen => Center(
          child: AspectRatio(aspectRatio: 16 / 9, child: FittedBox(fit: BoxFit.cover, child: player)),
        ),
      PlayerAspectRatio.standard => Center(
          child: AspectRatio(aspectRatio: 4 / 3, child: FittedBox(fit: BoxFit.cover, child: player)),
        ),
      PlayerAspectRatio.fit => Center(child: FittedBox(fit: BoxFit.contain, child: player)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;
    final Duration position = _displayedPosition;
    final Duration duration = controller?.value.duration ?? Duration.zero;
    final double progress = duration.inMilliseconds == 0
        ? 0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    final bool isPaused = controller != null &&
        controller.value.isInitialized &&
        !controller.value.isPlaying;

    return TvBackScope(
      onBack: () async {
        if (_channelListVisible) {
          _closeChannelList();
          return;
        }
        if (_tracksVisible) {
          _closeTracks();
          return;
        }
        _saveProgress();
        await _stopPlayback();
        if (mounted) {
          await popToPreviousPage(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: !_channelListVisible && !_tracksVisible,
          canRequestFocus: !_channelListVisible && !_tracksVisible,
          skipTraversal: _channelListVisible || _tracksVisible,
          focusNode: _focusNode,
          onKeyEvent: _onKey,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (controller != null && controller.value.isInitialized)
                _buildVideo(controller)
              else
                const ColoredBox(color: Colors.black),
              if (_loading)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.neonCyan),
                      if (context.read<SportModeRepository>().enabled) ...[
                        const SizedBox(height: 18),
                        const Text(
                          'Spor modu ayarlanıyor',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.neonCyan,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, color: AppColors.textPrimary),
                    ),
                  ),
                ),
              if (_osdVisible && widget.playlist.isNotEmpty)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(36, 48, 36, 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_index + 1}/${widget.playlist.length}  ${_current.title}',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (isPaused) ...[
                                const Icon(
                                  Icons.pause_circle_filled,
                                  color: AppColors.neonCyan,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  '${_current.category}  •  Ses $_selectedAudio  •  Altyazı $_selectedSubtitle'
                                  '${_reconnectAttempt > 0 ? '  •  Yeniden bağlanma $_reconnectAttempt/${_buffer.maxReconnectAttempts}' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Text(
                                _isOnDemand && duration > Duration.zero
                                    ? '${_formatDuration(position)} / ${_formatDuration(duration)}'
                                    : 'CANLI',
                                style: TextStyle(
                                  color: _pendingSeek != null
                                      ? AppColors.neonCyan
                                      : AppColors.textSecondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              color: AppColors.neonCyan,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isOnDemand
                                ? 'Sol/Sağ: 10 sn  •  Yukarı/Aşağı: 1 dk  •  OK: Duraklat  •  OK basılı: Ses/Altyazı  •  Geri: Çıkış'
                                : 'OK: Kanal listesi  •  OK basılı: Ses/Altyazı  •  Yukarı/Aşağı: Kanal  •  Geri: Çıkış',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_captionText != null && _captionText!.trim().isNotEmpty)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 150, left: 48, right: 48),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          _captionText!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_channelListVisible)
                Align(
                  alignment: Alignment.centerRight,
                  child: FocusScope(
                    autofocus: true,
                    child: _ChannelListPanel(
                      playlist: widget.playlist,
                      currentIndex: _index,
                      onSelected: _selectChannel,
                      onClose: _closeChannelList,
                    ),
                  ),
                ),
              if (_tracksVisible)
                Align(
                  alignment: Alignment.centerRight,
                  child: FocusScope(
                    autofocus: true,
                    child: _TracksPanel(
                      audioTracks: _audioTracks,
                      subtitleTracks: _subtitleTracks,
                      selectedAudio: _selectedAudio,
                      selectedSubtitle: _selectedSubtitle,
                      aspectLabel: _aspect.label,
                      onSelectAudio: _selectAudio,
                      onSelectSubtitle: _selectSubtitle,
                      onCycleAspect: () => _cycleAspect(true),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelListPanel extends StatefulWidget {
  const _ChannelListPanel({
    required this.playlist,
    required this.currentIndex,
    required this.onSelected,
    required this.onClose,
  });

  final List<PlayableItem> playlist;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onClose;

  @override
  State<_ChannelListPanel> createState() => _ChannelListPanelState();
}

class _ChannelListPanelState extends State<_ChannelListPanel> {
  static const double _itemExtent = 88;

  late final ScrollController _scrollController;

  // The panel is opened by an OK press that may still be held, so ignore
  // selections arriving from that same press.
  final DateTime _acceptingFrom = DateTime.now().add(const Duration(milliseconds: 600));

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: (widget.currentIndex * _itemExtent - _itemExtent * 2)
          .clamp(0, double.maxFinite),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 460,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.94),
        border: Border(
          left: BorderSide(color: AppColors.neonCyan.withValues(alpha: 0.45), width: 2),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(
                children: [
                  const Icon(Icons.playlist_play, color: AppColors.neonCyan, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Kanal Listesi',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${widget.playlist.length} kanal',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemExtent: _itemExtent,
                itemCount: widget.playlist.length,
                itemBuilder: (context, index) {
                  final PlayableItem item = widget.playlist[index];
                  final bool isCurrent = index == widget.currentIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NeonFocusCard(
                      autofocus: isCurrent,
                      focusedScale: 1.02,
                      unfocusedOpacity: isCurrent ? 1 : 0.7,
                      borderRadius: 14,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      onActivate: () {
                        if (DateTime.now().isAfter(_acceptingFrom)) {
                          widget.onSelected(index);
                        }
                      },
                      child: Row(
                        children: [
                          SizedBox(
                            width: 44,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isCurrent ? AppColors.neonCyan : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  item.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isCurrent)
                            const Icon(Icons.play_arrow_rounded, color: AppColors.neonCyan),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
              child: Text(
                'Kanal seçmek için OK, kapatmak için Geri tuşunu kullanınız.',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TracksPanel extends StatefulWidget {
  const _TracksPanel({
    required this.audioTracks,
    required this.subtitleTracks,
    required this.selectedAudio,
    required this.selectedSubtitle,
    required this.aspectLabel,
    required this.onSelectAudio,
    required this.onSelectSubtitle,
    required this.onCycleAspect,
  });

  final List<MediaTrack> audioTracks;
  final List<MediaTrack> subtitleTracks;
  final String selectedAudio;
  final String selectedSubtitle;
  final String aspectLabel;
  final ValueChanged<MediaTrack> onSelectAudio;
  final ValueChanged<MediaTrack> onSelectSubtitle;
  final VoidCallback onCycleAspect;

  @override
  State<_TracksPanel> createState() => _TracksPanelState();
}

class _TracksPanelState extends State<_TracksPanel> {
  static const Duration _acceptDelay = Duration(milliseconds: 500);

  final FocusNode _scopeFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late final DateTime _acceptingFrom;
  late int _cursor;

  List<MediaTrack> get _audio => widget.audioTracks;
  List<MediaTrack> get _subs => widget.subtitleTracks;
  int get _itemCount => _audio.length + _subs.length + 1;

  @override
  void initState() {
    super.initState();
    _acceptingFrom = DateTime.now().add(_acceptDelay);
    _cursor = _initialCursor();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scopeFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _scopeFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int _initialCursor() {
    final int audioIndex = _audio.indexWhere((track) => track.label == widget.selectedAudio);
    if (audioIndex >= 0) {
      return audioIndex;
    }
    return 0;
  }

  bool _canAccept() => DateTime.now().isAfter(_acceptingFrom);

  void _move(int delta) {
    if (_itemCount <= 0) {
      return;
    }
    setState(() {
      _cursor = (_cursor + delta) % _itemCount;
      if (_cursor < 0) {
        _cursor += _itemCount;
      }
    });
  }

  void _activate() {
    if (!_canAccept()) {
      return;
    }
    if (_cursor < _audio.length) {
      widget.onSelectAudio(_audio[_cursor]);
      return;
    }
    final int subIndex = _cursor - _audio.length;
    if (subIndex < _subs.length) {
      widget.onSelectSubtitle(_subs[subIndex]);
      return;
    }
    widget.onCycleAspect();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final LogicalKeyboardKey key = event.logicalKey;
    final bool isOk = key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (isOk) {
      if (event is KeyDownEvent && _canAccept()) {
        _activate();
      }
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _tile({
    required int index,
    required String label,
    required Color accent,
    required bool selected,
  }) {
    final bool highlighted = index == _cursor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedScale(
        scale: highlighted ? 1.03 : 1,
        duration: const Duration(milliseconds: 180),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted ? accent : AppColors.glassBorder,
              width: highlighted ? 3 : 1,
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.5),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? accent : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: _scopeFocus,
      onKeyEvent: _onKey,
      child: Container(
        width: 420,
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.95),
          border: Border(
            left: BorderSide(color: AppColors.neonPurple.withValues(alpha: 0.45), width: 2),
          ),
        ),
        child: SafeArea(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              const Text('Ses ve Altyazı', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              const Text('SES', style: TextStyle(color: AppColors.neonCyan, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (int i = 0; i < _audio.length; i++)
                _tile(
                  index: i,
                  label: _audio[i].label,
                  accent: AppColors.neonCyan,
                  selected: _audio[i].label == widget.selectedAudio,
                ),
              const SizedBox(height: 12),
              const Text('ALTYAZI', style: TextStyle(color: AppColors.neonPurple, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (int i = 0; i < _subs.length; i++)
                _tile(
                  index: _audio.length + i,
                  label: _subs[i].label,
                  accent: AppColors.neonPurple,
                  selected: _subs[i].label == widget.selectedSubtitle,
                ),
              const SizedBox(height: 12),
              const Text('GÖRÜNTÜ', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _tile(
                index: _audio.length + _subs.length,
                label: 'Görüntü oranı: ${widget.aspectLabel}',
                accent: AppColors.neonCyan,
                selected: false,
              ),
              const SizedBox(height: 16),
              const Text(
                'Yukarı/Aşağı ile seçiniz, OK ile onaylayınız, Geri ile kapatınız. Gömülü ses bazı yayınlarda değişmeyebilir.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
