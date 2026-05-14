import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../models/channel.dart';
import '../services/ad_manager.dart';
import '../theme/app_theme.dart';

class VideoPlayerScreen extends StatefulWidget {
  final List<Channel> channels;
  final int initialIndex;
  final bool isLive;
  final bool restoreToLandscape;

  const VideoPlayerScreen({
    super.key,
    required this.channels,
    required this.initialIndex,
    this.isLive = true,
    this.restoreToLandscape = false,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  late int _currentIndex;
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _isBuffering = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _canPop = false;
  BoxFit _videoFit = BoxFit.contain;
  double _volume = 100.0;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  // Track state
  List<SubtitleTrack> _subtitleTracks = [];
  List<VideoTrack> _videoTracks = [];
  SubtitleTrack _currentSubtitleTrack = SubtitleTrack.no();
  VideoTrack _currentVideoTrack = VideoTrack.auto();
  StreamSubscription<Tracks>? _tracksSubscription;
  StreamSubscription<Track>? _activeTrackSubscription;

  // Video resolution
  int? _videoWidth;
  int? _videoHeight;
  StreamSubscription<int?>? _widthSubscription;
  StreamSubscription<int?>? _heightSubscription;

  // ── NEW PREMIUM FEATURES ──
  // Double-tap seek feedback
  String? _seekLabel; // e.g. "+10s"
  bool _seekLeft = false;
  Timer? _seekLabelTimer;

  // Swipe gestures (brightness / volume)
  double _brightness = 1.0;
  bool _isSwipingBrightness = false; // true=left side, false=right side
  bool _showSwipeOverlay = false;
  Timer? _swipeOverlayTimer;

  // Long-press 2× speed
  bool _isFastForwarding = false;
  double _savedRate = 1.0;

  // Playback speed
  double _playbackRate = 1.0;

  // Screen lock
  bool _isLocked = false;

  // Sleep timer
  int? _sleepMinutes;
  Timer? _sleepTimer;
  int _sleepSecondsLeft = 0;

  // Resume position
  static const String _positionKey = 'resume_pos_';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _currentIndex = widget.initialIndex;
    _player = Player(
      configuration: const PlayerConfiguration(bufferSize: 32 * 1024 * 1024),
    );
    _controller = VideoController(_player);

    _player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    _player.stream.error.listen((error) {
      if (mounted && error.isNotEmpty) {
        if (error.contains('audio device') || error.contains('no sound')) {
          debugPrint('media_kit audio warning (non-fatal): $error');
          return;
        }
        setState(() {
          _hasError = true;
          _errorMessage = error;
        });
      }
    });

    _positionSubscription = _player.stream.position.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _durationSubscription = _player.stream.duration.listen((d) {
      if (mounted) {
        setState(() => _duration = d);
        _checkResumeOnce();
      }
    });

    // Listen to available tracks
    _tracksSubscription = _player.stream.tracks.listen((tracks) {
      if (mounted) {
        setState(() {
          _subtitleTracks = tracks.subtitle;
          _videoTracks = tracks.video;
        });
      }
    });

    // Listen to active track selections (subtitle + video in one stream)
    _activeTrackSubscription = _player.stream.track.listen((track) {
      if (mounted) {
        setState(() {
          _currentSubtitleTrack = track.subtitle;
          _currentVideoTrack = track.video;
        });
      }
    });

    // Listen to video resolution
    _widthSubscription = _player.stream.width.listen((w) {
      if (mounted) setState(() => _videoWidth = w);
    });
    _heightSubscription = _player.stream.height.listen((h) {
      if (mounted) setState(() => _videoHeight = h);
    });

    _openCurrentChannel();
    _initBrightness();

    _startControlsTimer();
  }

  Future<void> _initBrightness() async {
    try {
      _brightness = await ScreenBrightness().current;
    } catch (_) {}
  }

  Future<void> _savePosition() async {
    if (widget.isLive || _duration == Duration.zero) return;
    final key =
        '$_positionKey${widget.channels[_currentIndex].streamUrl.hashCode}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, _position.inSeconds);
  }

  Future<void> _loadAndResumePosition() async {
    if (widget.isLive || _duration == Duration.zero) return;
    final key =
        '$_positionKey${widget.channels[_currentIndex].streamUrl.hashCode}';
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(key);
    if (saved != null && saved > 10) {
      await _player.seek(Duration(seconds: saved));
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (widget.restoreToLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _tracksSubscription?.cancel();
    _activeTrackSubscription?.cancel();
    _widthSubscription?.cancel();
    _heightSubscription?.cancel();
    _seekLabelTimer?.cancel();
    _swipeOverlayTimer?.cancel();
    _sleepTimer?.cancel();
    _controlsTimer?.cancel();
    _savePosition();
    ScreenBrightness().resetScreenBrightness();
    _player.dispose();
    super.dispose();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _cancelControlsTimer() {
    _controlsTimer?.cancel();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startControlsTimer();
    } else {
      _cancelControlsTimer();
    }
  }

  void _openCurrentChannel() {
    if (_currentIndex < 0 || _currentIndex >= widget.channels.length) return;
    setState(() {
      _hasError = false;
      _isBuffering = true;
    });
    _player.open(Media(widget.channels[_currentIndex].streamUrl));
  }

  void _nextChannel() {
    if (_currentIndex < widget.channels.length - 1) {
      setState(() => _currentIndex++);
      _openCurrentChannel();
    }
  }

  void _prevChannel() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _openCurrentChannel();
    }
  }

  void _toggleVideoFit() {
    setState(() {
      if (_videoFit == BoxFit.contain) {
        _videoFit = BoxFit.cover;
      } else if (_videoFit == BoxFit.cover) {
        _videoFit = BoxFit.fill;
      } else {
        _videoFit = BoxFit.contain;
      }
    });
  }

  // ── DOUBLE-TAP SEEK ──
  void _onDoubleTapSeek(bool isLeft) {
    if (widget.isLive) return;
    final seconds = isLeft ? -10 : 10;
    final newPos = _position + Duration(seconds: seconds);
    _player.seek(newPos.isNegative ? Duration.zero : newPos);
    setState(() {
      _seekLabel = '${seconds > 0 ? "+" : ""}${seconds}s';
      _seekLeft = isLeft;
    });
    _seekLabelTimer?.cancel();
    _seekLabelTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _seekLabel = null);
    });
  }

  // ── SWIPE: BRIGHTNESS (left half) / VOLUME (right half) ──
  void _onVerticalDragStart(DragStartDetails d, BuildContext context) {
    final midX = MediaQuery.of(context).size.width / 2;
    _isSwipingBrightness = d.globalPosition.dx < midX;
  }

  void _onVerticalDragUpdate(DragUpdateDetails d, BuildContext ctx) {
    final screenHeight = MediaQuery.of(ctx).size.height;
    final delta = -d.delta.dy / screenHeight;
    if (_isSwipingBrightness) {
      final newBrightness = (_brightness + delta * 2).clamp(0.0, 1.0);
      _brightness = newBrightness;
      ScreenBrightness().setScreenBrightness(newBrightness);
    } else {
      final newVol = (_volume + delta * 200).clamp(0.0, 100.0);
      setState(() => _volume = newVol);
      _player.setVolume(newVol);
    }
    setState(() => _showSwipeOverlay = true);
    _swipeOverlayTimer?.cancel();
    _swipeOverlayTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showSwipeOverlay = false);
    });
  }

  // ── LONG PRESS: 2× SPEED ──
  void _onLongPressStart(LongPressStartDetails _) {
    _savedRate = _playbackRate;
    setState(() => _isFastForwarding = true);
    _player.setRate(2.0);
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    setState(() => _isFastForwarding = false);
    _player.setRate(_savedRate);
  }

  // ── LOCK SCREEN ──
  void _toggleLock() => setState(() => _isLocked = !_isLocked);

  // ── SLEEP TIMER ──
  void _showSleepTimerDialog() async {
    final options = [15, 30, 60, 90, 0];
    final labels = ['15 min', '30 min', '60 min', '90 min', 'Off'];
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => _buildTrackDialog(
        title: 'Sleep Timer',
        icon: Icons.bedtime_rounded,
        children: List.generate(options.length, (i) {
          final isActive =
              _sleepMinutes == (options[i] == 0 ? null : options[i]);
          return _TrackOption(
            label: labels[i],
            isActive: isActive,
            onTap: () => Navigator.pop(ctx, options[i]),
          );
        }),
      ),
    );
    if (!mounted || selected == null) return;
    _sleepTimer?.cancel();
    if (selected == 0) {
      setState(() {
        _sleepMinutes = null;
        _sleepSecondsLeft = 0;
      });
    } else {
      setState(() {
        _sleepMinutes = selected;
        _sleepSecondsLeft = selected * 60;
      });
      _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _sleepSecondsLeft--);
        if (_sleepSecondsLeft <= 0) {
          t.cancel();
          _player.pause();
          setState(() {
            _sleepMinutes = null;
            _sleepSecondsLeft = 0;
          });
        }
      });
    }
  }

  // ── SPEED SELECTOR ──
  void _showSpeedDialog() async {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final labels = ['0.5×', '0.75×', '1× (Normal)', '1.25×', '1.5×', '2×'];
    final selected = await showDialog<double>(
      context: context,
      builder: (ctx) => _buildTrackDialog(
        title: 'Playback Speed',
        icon: Icons.speed_rounded,
        children: List.generate(
          speeds.length,
          (i) => _TrackOption(
            label: labels[i],
            isActive: _playbackRate == speeds[i],
            onTap: () => Navigator.pop(ctx, speeds[i]),
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _playbackRate = selected);
    _player.setRate(selected);
  }

  // ── RESUME POSITION: called once duration is known ──
  bool _resumeChecked = false;
  void _checkResumeOnce() {
    if (_resumeChecked || _duration == Duration.zero) return;
    _resumeChecked = true;
    _loadAndResumePosition();
  }

  void _onSubtitlePressed() async {
    final tracks = List<SubtitleTrack>.from(_subtitleTracks);
    // Always include a "No Subtitles" option
    if (!tracks.any((t) => t == SubtitleTrack.no())) {
      tracks.insert(0, SubtitleTrack.no());
    }

    if (tracks.length <= 1 && tracks.first == SubtitleTrack.no()) {
      // No subtitle tracks available
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No subtitle tracks available for this stream'),
          ),
        );
      }
      return;
    }

    final selected = await showDialog<SubtitleTrack>(
      context: context,
      builder: (ctx) => _buildTrackDialog(
        title: 'Select Subtitle',
        icon: Icons.subtitles_rounded,
        children: tracks.map((track) {
          final isActive = track.id == _currentSubtitleTrack.id;
          final label = _subtitleTrackLabel(track);
          return _TrackOption(
            label: label,
            isActive: isActive,
            onTap: () => Navigator.pop(ctx, track),
          );
        }).toList(),
      ),
    );
    if (!mounted || selected == null) return;
    _player.setSubtitleTrack(selected);
    setState(() => _currentSubtitleTrack = selected);
  }

  void _onQualityPressed() async {
    // Filter out VideoTrack.no() — it disables video entirely, not a quality option
    final tracks = _videoTracks.where((t) => t != VideoTrack.no()).toList();

    // Prepend Auto if missing
    if (!tracks.any((t) => t == VideoTrack.auto())) {
      tracks.insert(0, VideoTrack.auto());
    }

    // Current resolution string for the dialog subtitle
    final currentRes = (_videoWidth != null && _videoHeight != null)
        ? '$_videoWidth×$_videoHeight · ${_heightToQualityLabel(_videoHeight!)}'
              .trim()
        : null;

    if (tracks.length <= 1) {
      if (mounted) {
        final resText = currentRes != null ? ' ($currentRes)' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Single quality stream$resText — no alternatives available',
            ),
          ),
        );
      }
      return;
    }

    final selected = await showDialog<VideoTrack>(
      context: context,
      builder: (ctx) => _buildTrackDialog(
        title: 'Select Quality',
        icon: Icons.high_quality_rounded,
        subtitle: currentRes,
        children: tracks.asMap().entries.map((entry) {
          final idx = entry.key;
          final track = entry.value;
          final isActive = track.id == _currentVideoTrack.id;
          final label = _videoTrackLabel(track, idx);
          return _TrackOption(
            label: label,
            isActive: isActive,
            badge: (isActive && currentRes != null) ? currentRes : null,
            onTap: () => Navigator.pop(ctx, track),
          );
        }).toList(),
      ),
    );
    if (!mounted || selected == null) return;
    _player.setVideoTrack(selected);
    setState(() => _currentVideoTrack = selected);
  }

  String _subtitleTrackLabel(SubtitleTrack track) {
    if (track == SubtitleTrack.no()) return 'Off';
    final parts = <String>[];
    if (track.language != null && track.language!.isNotEmpty) {
      parts.add(track.language!);
    }
    if (track.title != null && track.title!.isNotEmpty) parts.add(track.title!);
    if (parts.isEmpty) parts.add('Track ${track.id}');
    return parts.join(' – ');
  }

  String _videoTrackLabel(VideoTrack track, [int index = 0]) {
    if (track == VideoTrack.auto()) return 'Auto';
    final parts = <String>[];
    if (track.title != null && track.title!.isNotEmpty) {
      // Track title sometimes already contains resolution like "1920x1080"
      final title = track.title!;
      final resMatch = RegExp(r'(\d{3,4})x(\d{3,4})').firstMatch(title);
      if (resMatch != null) {
        final h = int.tryParse(resMatch.group(2) ?? '');
        if (h != null) return _heightToQualityLabel(h);
      }
      parts.add(title);
    }
    if (track.language != null && track.language!.isNotEmpty) {
      parts.add(track.language!);
    }
    if (parts.isEmpty) {
      // Use a descriptive fallback with track index
      final qualityLabels = ['Low', 'Medium', 'High', 'Ultra'];
      final label = index < qualityLabels.length
          ? qualityLabels[index]
          : 'Quality ${index + 1}';
      return label;
    }
    return parts.join(' – ');
  }

  /// Maps a pixel height to a human-readable quality label.
  String _heightToQualityLabel(int height) {
    if (height >= 2160) return '4K UHD';
    if (height >= 1440) return '1440p QHD';
    if (height >= 1080) return '1080p FHD';
    if (height >= 720) return '720p HD';
    if (height >= 480) return '480p SD';
    if (height >= 360) return '360p';
    if (height >= 240) return '240p';
    return '${height}p';
  }

  Widget _buildTrackDialog({
    required String title,
    required IconData icon,
    required List<_TrackOption> children,
    String? subtitle,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 520),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: AppTheme.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'Now playing: $subtitle',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Divider(color: Colors.white12, height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '00:00';
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    final s = duration.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:$mm:$ss';
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _player.pause();
        AdManager.instance.showInterstitialAd(
          onAdClosed: () {
            if (mounted) {
              setState(() => _canPop = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.pop(context);
              });
            }
          },
        );
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Builder(
          builder: (ctx) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isLocked ? _toggleLock : _toggleControls,
              onDoubleTapDown: (d) {
                if (_isLocked) return;
                final mid = MediaQuery.of(ctx).size.width / 2;
                _onDoubleTapSeek(d.globalPosition.dx < mid);
              },
              onDoubleTap: () {},
              onVerticalDragStart: _isLocked
                  ? null
                  : (d) => _onVerticalDragStart(d, ctx),
              onVerticalDragUpdate: _isLocked
                  ? null
                  : (d) => _onVerticalDragUpdate(d, ctx),
              onLongPressStart: _isLocked ? null : _onLongPressStart,
              onLongPressEnd: _isLocked ? null : _onLongPressEnd,
              child: Stack(
                children: [
                  // Video
                  Positioned.fill(
                    child: Video(
                      controller: _controller,
                      controls: NoVideoControls,
                      fill: Colors.black,
                      fit: _videoFit,
                    ),
                  ),

                  // Buffering
                  if (_isBuffering && !_hasError)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primary,
                        strokeWidth: 3,
                      ),
                    ),

                  // Error
                  if (_hasError)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.all(32),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: AppTheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Playback Error',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _openCurrentChannel,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Controls overlay
                  AnimatedOpacity(
                    opacity: (!_isLocked && _showControls) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: _isLocked || !_showControls,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.7),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                            stops: const [0.0, 0.25, 0.75, 1.0],
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Top bar
                            SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_back_ios_rounded,
                                        color: Colors.white,
                                      ),
                                      onPressed: () =>
                                          Navigator.maybePop(context),
                                    ),
                                    Expanded(
                                      child: Text(
                                        widget.channels[_currentIndex].name,
                                        style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (widget.isLive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.error,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'LIVE',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                    if (_playbackRate != 1.0)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(
                                            alpha: 0.85,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          '$_playbackRate×',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(
                                        _isLocked
                                            ? Icons.lock_rounded
                                            : Icons.lock_open_rounded,
                                        color: _isLocked
                                            ? AppTheme.primary
                                            : Colors.white,
                                        size: 20,
                                      ),
                                      tooltip: _isLocked
                                          ? 'Unlock'
                                          : 'Lock Screen',
                                      onPressed: _toggleLock,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.speed_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      tooltip: 'Playback Speed',
                                      onPressed: _showSpeedDialog,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.bedtime_rounded,
                                        color: _sleepMinutes != null
                                            ? AppTheme.primary
                                            : Colors.white,
                                        size: 20,
                                      ),
                                      tooltip: 'Sleep Timer',
                                      onPressed: _showSleepTimerDialog,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Center controls
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildControlButton(
                                  icon: Icons.skip_previous_rounded,
                                  onPressed: _currentIndex > 0
                                      ? _prevChannel
                                      : null,
                                  size: 32,
                                ),
                                const SizedBox(width: 40),
                                StreamBuilder<bool>(
                                  stream: _player.stream.playing,
                                  builder: (context, snapshot) {
                                    final playing = snapshot.data ?? false;
                                    return GestureDetector(
                                      onTap: () => _player.playOrPause(),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.5,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          playing
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 40),
                                _buildControlButton(
                                  icon: Icons.skip_next_rounded,
                                  onPressed:
                                      _currentIndex < widget.channels.length - 1
                                      ? _nextChannel
                                      : null,
                                  size: 32,
                                ),
                              ],
                            ),

                            // Seeker + bottom bar
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!widget.isLive)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _formatDuration(_position),
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Colors.white.withValues(
                                                  alpha: 0.8,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _formatDuration(_duration),
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Colors.white.withValues(
                                                  alpha: 0.8,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SliderTheme(
                                          data: SliderTheme.of(context)
                                              .copyWith(
                                                activeTrackColor:
                                                    AppTheme.primary,
                                                inactiveTrackColor:
                                                    Colors.white24,
                                                thumbColor: AppTheme.primary,
                                                overlayColor: AppTheme.primary
                                                    .withValues(alpha: 0.2),
                                                thumbShape:
                                                    const RoundSliderThumbShape(
                                                      enabledThumbRadius: 8,
                                                    ),
                                                trackHeight: 4,
                                              ),
                                          child: Slider(
                                            value: _position.inMilliseconds
                                                .toDouble()
                                                .clamp(
                                                  0.0,
                                                  _duration.inMilliseconds
                                                          .toDouble() +
                                                      1.0,
                                                ),
                                            min: 0.0,
                                            max:
                                                _duration.inMilliseconds
                                                        .toDouble() >
                                                    0
                                                ? _duration.inMilliseconds
                                                      .toDouble()
                                                : 1.0,
                                            onChanged: (v) => _player.seek(
                                              Duration(milliseconds: v.toInt()),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                SafeArea(
                                  top: false,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      16,
                                    ),
                                    child: Row(
                                      children: [
                                        const Spacer(),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.subtitles_rounded,
                                            color: Colors.white,
                                          ),
                                          tooltip: 'Subtitles',
                                          onPressed: _onSubtitlePressed,
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.high_quality_rounded,
                                            color: Colors.white,
                                          ),
                                          tooltip: 'Quality',
                                          onPressed: _onQualityPressed,
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            _videoFit == BoxFit.contain
                                                ? Icons.fullscreen_rounded
                                                : _videoFit == BoxFit.cover
                                                ? Icons.zoom_out_map_rounded
                                                : Icons.fit_screen_rounded,
                                            color: Colors.white,
                                          ),
                                          tooltip: 'Screen Fit',
                                          onPressed: _toggleVideoFit,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Right-side vertical volume slider
                  Positioned(
                    right: 16,
                    top: 0,
                    bottom: 0,
                    child: AnimatedOpacity(
                      opacity: (!_isLocked && _showControls) ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: IgnorePointer(
                        ignoring: _isLocked || !_showControls,
                        child: Center(
                          child: _VerticalVolumeSlider(
                            volume: _volume,
                            onVolumeChanged: (v) {
                              setState(() => _volume = v);
                              _player.setVolume(v);
                            },
                            onChangeStart: _cancelControlsTimer,
                            onChangeEnd: _startControlsTimer,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── DOUBLE-TAP SEEK FLASH ──
                  if (_seekLabel != null)
                    Positioned(
                      left: _seekLeft ? 20 : null,
                      right: _seekLeft ? null : 20,
                      top: 0,
                      bottom: 0,
                      width: 120,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _seekLeft
                                    ? Icons.fast_rewind_rounded
                                    : Icons.fast_forward_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _seekLabel!,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── SWIPE OVERLAY (brightness / volume) ──
                  if (_showSwipeOverlay)
                    Positioned(
                      left: _isSwipingBrightness ? 20 : null,
                      right: _isSwipingBrightness ? null : 80,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isSwipingBrightness
                                    ? (_brightness > 0.5
                                          ? Icons.brightness_high_rounded
                                          : Icons.brightness_low_rounded)
                                    : (_volume > 50
                                          ? Icons.volume_up_rounded
                                          : Icons.volume_down_rounded),
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isSwipingBrightness
                                    ? '${(_brightness * 100).round()}%'
                                    : '${_volume.round()}%',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── FAST-FORWARD INDICATOR ──
                  if (_isFastForwarding)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.fast_forward_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '2× Speed',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── LOCK OVERLAY ──
                  if (_isLocked)
                    Positioned(
                      top: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _toggleLock,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.lock_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Tap to unlock',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── SLEEP TIMER COUNTDOWN BADGE ──
                  if (_sleepMinutes != null && !_isLocked)
                    Positioned(
                      bottom: 80,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bedtime_rounded,
                              color: Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sleep: ${_sleepSecondsLeft ~/ 60}m ${_sleepSecondsLeft % 60}s',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    double size = 24,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: size),
      style: IconButton.styleFrom(disabledForegroundColor: Colors.white24),
    );
  }
}

class _VerticalVolumeSlider extends StatefulWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;

  const _VerticalVolumeSlider({
    required this.volume,
    required this.onVolumeChanged,
    this.onChangeStart,
    this.onChangeEnd,
  });

  @override
  State<_VerticalVolumeSlider> createState() => _VerticalVolumeSliderState();
}

class _VerticalVolumeSliderState extends State<_VerticalVolumeSlider> {
  late double _localVolume;

  @override
  void initState() {
    super.initState();
    _localVolume = widget.volume;
  }

  void _set(double v) {
    final clamped = v.clamp(0.0, 100.0);
    setState(() => _localVolume = clamped);
    widget.onVolumeChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              widget.onChangeStart?.call();
              _set(_localVolume == 0 ? 100.0 : 0.0);
              widget.onChangeEnd?.call();
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Icon(
                _localVolume == 0
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppTheme.primary,
                  inactiveTrackColor: Colors.white30,
                  thumbColor: AppTheme.primary,
                  overlayColor: AppTheme.primary.withValues(alpha: 0.2),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _localVolume,
                  min: 0,
                  max: 100,
                  onChanged: _set,
                  onChangeStart: (_) => widget.onChangeStart?.call(),
                  onChangeEnd: (_) => widget.onChangeEnd?.call(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TrackOption extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final String? badge;

  const _TrackOption({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? AppTheme.primary : Colors.white,
                    ),
                  ),
                  if (isActive && badge != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      badge!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.primary.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isActive)
              Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
