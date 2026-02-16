import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../services/pip_service.dart';
import 'mobile_player_controls.dart';
import 'pc_player_controls.dart';
import 'video_player_surface.dart';

class VideoPlayerWidget extends StatefulWidget {
  final VideoPlayerSurface surface;
  final String? url;
  final Map<String, String>? headers;
  final VoidCallback? onBackPressed;
  final Function(VideoPlayerWidgetController)? onControllerCreated;
  final VoidCallback? onReady;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onVideoCompleted;
  final VoidCallback? onPause;
  final bool isLastEpisode;
  final Function(dynamic)? onCastStarted;
  final String? videoTitle;
  final int? currentEpisodeIndex;
  final int? totalEpisodes;
  final String? sourceName;
  final Function(bool isWebFullscreen)? onWebFullscreenChanged;
  final VoidCallback? onExitFullScreen;
  final bool live;
  final Function(bool isPipMode)? onPipModeChanged;
  final Function(int width, int height)? onVideoSizeChanged;

  const VideoPlayerWidget({
    super.key,
    this.surface = VideoPlayerSurface.mobile,
    this.url,
    this.headers,
    this.onBackPressed,
    this.onControllerCreated,
    this.onReady,
    this.onNextEpisode,
    this.onVideoCompleted,
    this.onPause,
    this.isLastEpisode = false,
    this.onCastStarted,
    this.videoTitle,
    this.currentEpisodeIndex,
    this.totalEpisodes,
    this.sourceName,
    this.onWebFullscreenChanged,
    this.onExitFullScreen,
    this.live = false,
    this.onPipModeChanged,
    this.onVideoSizeChanged,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class VideoPlayerWidgetController {
  VideoPlayerWidgetController._(this._state);
  final _VideoPlayerWidgetState _state;

  Future<void> updateDataSource(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
  }) async {
    await _state._updateDataSource(
      url,
      startAt: startAt,
      headers: headers,
    );
  }

  Future<void> seekTo(Duration position) async {
    await _state._player?.seek(position);
  }

  Duration? get currentPosition => _state._player?.state.position;

  Duration? get duration => _state._player?.state.duration;

  bool get isPlaying => _state._player?.state.playing ?? false;

  Future<void> pause() async {
    await _state._player?.pause();
  }

  Future<void> play() async {
    await _state._player?.play();
  }

  void addProgressListener(VoidCallback listener) {
    _state._addProgressListener(listener);
  }

  void removeProgressListener(VoidCallback listener) {
    _state._removeProgressListener(listener);
  }

  Future<void> setSpeed(double speed) async {
    await _state._setPlaybackSpeed(speed);
  }

  double get playbackSpeed => _state._playbackSpeed.value;

  Future<void> setVolume(double volume) async {
    await _state._player?.setVolume(volume);
  }

  double? get volume => _state._player?.state.volume;

  void exitWebFullscreen() {
    _state._exitWebFullscreen();
  }

  Future<void> dispose() async {
    await _state._externalDispose();
  }

  bool get isPipMode => _state._isPipMode;
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with WidgetsBindingObserver {
  Player? _player;
  VideoController? _videoController;
  bool _isInitialized = false;
  bool _hasCompleted = false;
  bool _isLoadingVideo = false;
  String? _currentUrl;
  Map<String, String>? _currentHeaders;
  final List<VoidCallback> _progressListeners = [];
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  final ValueNotifier<double> _playbackSpeed = ValueNotifier<double>(1.0);
  bool _playerDisposed = false;
  VoidCallback? _exitWebFullscreenCallback;
  bool _isPipMode = false;
  StreamSubscription<bool>? _pipModeSubscription;

  // 视频尺寸跟踪，用于动态设置 PiP 宽高比
  int? _videoWidth;
  int? _videoHeight;

  // 用于获取视频区域位置的 GlobalKey
  final GlobalKey _videoKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUrl = widget.url;
    _currentHeaders = widget.headers;
    _initializePlayer();
    _listenToNativePipMode();
    widget.onControllerCreated?.call(VideoPlayerWidgetController._(this));
  }
  
  /// 监听原生 PiP 模式变化
  void _listenToNativePipMode() {
    if (Platform.isAndroid) {
      PipService().initialize();
      _pipModeSubscription = PipService().onPipModeChanged.listen((isPipMode) {
        if (!mounted) return;
        debugPrint('Native PiP mode changed: $isPipMode');
        setState(() {
          _isPipMode = isPipMode;
        });
        widget.onPipModeChanged?.call(isPipMode);
      });
    }
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.headers != oldWidget.headers && widget.headers != null) {
      _currentHeaders = widget.headers;
    }
    if (widget.url != oldWidget.url && widget.url != null) {
      unawaited(_updateDataSource(widget.url!));
    }
  }

  Future<void> _initializePlayer() async {
    if (_playerDisposed) {
      return;
    }
    _player = Player();
    _videoController = VideoController(_player!);
    _setupPlayerListeners();
    if (_currentUrl != null) {
      await _openCurrentMedia();
    }
    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _openCurrentMedia({Duration? startAt}) async {
    if (_playerDisposed || _player == null || _currentUrl == null) {
      return;
    }
    setState(() {
      _isLoadingVideo = true;
    });
    try {
      await _player!.open(
        Media(
          _currentUrl!,
          start: startAt,
          httpHeaders: _currentHeaders ?? const <String, String>{},
        ),
        play: true,
      );
      await _player!.setRate(_playbackSpeed.value);
      setState(() {
        _hasCompleted = false;
        // _isLoadingVideo = false;
      });
      // widget.onReady?.call();
    } catch (error) {
      debugPrint('VideoPlayerWidget: failed to open media $error');
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
        });
      }
    }
  }

  void _setupPlayerListeners() {
    if (_player == null) {
      return;
    }
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    _completedSubscription?.cancel();
    _durationSubscription?.cancel();

    _positionSubscription = _player!.stream.position.listen((_) {
      for (final listener in List<VoidCallback>.from(_progressListeners)) {
        try {
          listener();
        } catch (error) {
          debugPrint('VideoPlayerWidget: progress listener error $error');
        }
      }
    });

    _playingSubscription = _player!.stream.playing.listen((playing) {
      if (!mounted) return;
      if (!playing) {
        setState(() {
          _hasCompleted = false;
        });
      }
    });

    if (!widget.live) {
      _completedSubscription = _player!.stream.completed.listen((completed) {
        if (!mounted) return;
        if (completed && !_hasCompleted) {
          _hasCompleted = true;
          widget.onVideoCompleted?.call();
        }
      });
    }

    _durationSubscription = _player!.stream.duration.listen((duration) {
      if (!mounted) return;
      if (duration != Duration.zero) {
        if (_isLoadingVideo) {
          setState(() {
            _isLoadingVideo = false;
          });
        }
        widget.onReady?.call();
      }
    });
    
    // 监听视频尺寸变化，用于 PiP 宽高比计算和竖屏视频布局
    _player!.stream.width.listen((width) {
      if (!mounted) return;
      _videoWidth = width?.toInt();
      _notifyVideoSizeChanged();
    });

    _player!.stream.height.listen((height) {
      if (!mounted) return;
      _videoHeight = height?.toInt();
      _notifyVideoSizeChanged();
    });
  }
  
  /// 通知父组件视频尺寸变化
  void _notifyVideoSizeChanged() {
    if (_videoWidth != null && _videoHeight != null) {
      widget.onVideoSizeChanged?.call(_videoWidth!, _videoHeight!);
    }
  }
  


  Future<void> _updateDataSource(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
  }) async {
    if (_playerDisposed) {
      return;
    }
    _currentUrl = url;
    if (headers != null) {
      _currentHeaders = headers;
    }

    if (_player == null) {
      await _initializePlayer();
      return;
    }

    setState(() {
      _isLoadingVideo = true;
    });

    try {
      final currentSpeed = _player!.state.rate;
      await _player!.open(
        Media(
          url,
          start: startAt,
          httpHeaders: _currentHeaders ?? const <String, String>{},
        ),
        play: true,
      );
      _playbackSpeed.value = currentSpeed;
      await _player!.setRate(currentSpeed);
      if (mounted) {
        setState(() {
          _hasCompleted = false;
          // _isLoadingVideo = false;
        });
      }
      // widget.onReady?.call();
    } catch (error) {
      debugPrint('VideoPlayerWidget: error while changing source $error');
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
        });
      }
    }
  }

  void _addProgressListener(VoidCallback listener) {
    if (!_progressListeners.contains(listener)) {
      _progressListeners.add(listener);
    }
  }

  void _removeProgressListener(VoidCallback listener) {
    _progressListeners.remove(listener);
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    _playbackSpeed.value = speed;
    await _player?.setRate(speed);
  }

  void _exitWebFullscreen() {
    _exitWebFullscreenCallback?.call();
  }



  /// 计算最大公约数
  int _gcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a;
  }

  Future<void> _enterPipMode() async {
    debugPrint('VideoPlayerWidget: _enterPipMode called');
    
    if (!mounted) return;
    
    // 防止重复调用
    if (_isPipMode) {
      debugPrint('Already in PiP mode, skip');
      return;
    }

    // 1. 等待视频尺寸可用（最多等待 500ms）
    int waitCount = 0;
    while ((_videoWidth == null || _videoHeight == null) && waitCount < 5) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }
    
    if (!mounted) return;

    // 2. 计算精确的宽高比
    int aspectX = 16;
    int aspectY = 9;
    
    if (_videoWidth != null && _videoHeight != null && 
        _videoWidth! > 0 && _videoHeight! > 0) {
      // 使用最大公约数简化比例，得到精确宽高比
      final gcd = _gcd(_videoWidth!, _videoHeight!);
      aspectX = (_videoWidth! / gcd).round();
      aspectY = (_videoHeight! / gcd).round();
      
      // 确保比例在 Android 允许范围内 (0.418 到 2.39)
      final ratio = aspectX / aspectY;
      if (ratio > 2.39) {
        aspectX = 239;
        aspectY = 100;
      } else if (ratio < 0.418) {
        aspectX = 100;
        aspectY = 239;
      }
    }
    debugPrint('PiP aspect ratio: $aspectX:$aspectY (video: ${_videoWidth}x${_videoHeight})');
    
    // 3. 获取视频区域的精确屏幕坐标
    Rect? sourceRect;
    try {
      final renderBox = _videoKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        sourceRect = Rect.fromLTWH(
          position.dx,
          position.dy,
          renderBox.size.width,
          renderBox.size.height,
        );
        debugPrint('PiP source rect: $sourceRect');
      }
    } catch (e) {
      debugPrint('Failed to get video rect: $e');
    }
    
    // 4. 调用原生 PiP
    // 注意：状态会通过 _listenToNativePipMode 的回调自动更新
    // 不需要在这里手动设置 _isPipMode
    if (Platform.isAndroid) {
      try {
        final success = await PipService().enterPipMode(
          aspectRatioX: aspectX,
          aspectRatioY: aspectY,
          sourceRect: sourceRect,
        );
        debugPrint('PiP enter result: $success');
        
        if (success) {
          // 确保播放继续
          await _player?.play();
          debugPrint('PiP entered successfully, video playing');
          // 状态会通过原生回调 onPipModeChanged 自动更新
        } else {
          debugPrint('PiP enter returned false');
        }
      } catch (e) {
        debugPrint('Native PiP failed: $e');
      }
    }
  }

  Future<void> _externalDispose() async {
    if (!mounted || _playerDisposed) {
      return;
    }
    await _disposePlayer();
  }

  Future<void> _disposePlayer() async {
    if (_playerDisposed) {
      return;
    }
    _playerDisposed = true;
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    _completedSubscription?.cancel();
    _durationSubscription?.cancel();
    _progressListeners.clear();
    await _player?.dispose();
    _player = null;
    _videoController = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_player == null) {
      return;
    }
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
      case AppLifecycleState.resumed:
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pipModeSubscription?.cancel();
    _disposePlayer();
    _playbackSpeed.dispose();
    super.dispose();
  }

  /// 自定义全屏回调：根据视频方向设置正确的屏幕方向
  Future<void> _onEnterFullscreen() async {
    // 判断视频方向
    final isPortrait = _videoHeight != null && 
                       _videoWidth != null && 
                       _videoHeight! > _videoWidth!;
    
    debugPrint('_onEnterFullscreen: _videoWidth=$_videoWidth, _videoHeight=$_videoHeight, isPortrait=$isPortrait');
    
    try {
      // 设置沉浸式模式
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
      
      // 根据视频方向设置屏幕方向
      if (isPortrait) {
        // 竖屏视频：锁定为竖屏
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      } else {
        // 横屏视频：锁定为横屏
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    } catch (e) {
      debugPrint('_onEnterFullscreen error: $e');
    }
  }

  /// 自定义退出全屏回调：恢复所有方向
  Future<void> _onExitFullscreen() async {
    debugPrint('_onExitFullscreen');
    
    try {
      // 恢复系统 UI
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
      
      // 恢复所有方向
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (e) {
      debugPrint('_onExitFullscreen error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _videoKey,  // 绑定 GlobalKey 用于获取视频区域位置
      color: Colors.black,
      child: _isInitialized && _videoController != null
          ? Video(
              controller: _videoController!,
              onEnterFullscreen: _onEnterFullscreen,
              onExitFullscreen: _onExitFullscreen,
              controls: (state) {
                // PiP 模式下不显示控制层，只显示视频
                if (_isPipMode) {
                  return const SizedBox.shrink();
                }
                
                return widget.surface == VideoPlayerSurface.desktop
                    ? PCPlayerControls(
                        state: state,
                        player: _player!,
                        onBackPressed: widget.onBackPressed,
                        onNextEpisode: widget.onNextEpisode,
                        onPause: widget.onPause,
                        videoUrl: _currentUrl ?? '',
                        isLastEpisode: widget.isLastEpisode,
                        isLoadingVideo: _isLoadingVideo,
                        onCastStarted: widget.onCastStarted,
                        videoTitle: widget.videoTitle,
                        currentEpisodeIndex: widget.currentEpisodeIndex,
                        totalEpisodes: widget.totalEpisodes,
                        sourceName: widget.sourceName,
                        onWebFullscreenChanged: widget.onWebFullscreenChanged,
                        onExitWebFullscreenCallbackReady: (callback) {
                          _exitWebFullscreenCallback = callback;
                        },
                        onExitFullScreen: widget.onExitFullScreen,
                        live: widget.live,
                        playbackSpeedListenable: _playbackSpeed,
                        onSetSpeed: _setPlaybackSpeed,
                      )
                    : MobilePlayerControls(
                        player: _player!,
                        state: state,
                        onControlsVisibilityChanged: (_) {},
                        onBackPressed: widget.onBackPressed,
                        onFullscreenChange: (_) {},
                        onNextEpisode: widget.onNextEpisode,
                        onPause: widget.onPause,
                        videoUrl: _currentUrl ?? '',
                        isLastEpisode: widget.isLastEpisode,
                        isLoadingVideo: _isLoadingVideo,
                        onCastStarted: widget.onCastStarted,
                        videoTitle: widget.videoTitle,
                        currentEpisodeIndex: widget.currentEpisodeIndex,
                        totalEpisodes: widget.totalEpisodes,
                        sourceName: widget.sourceName,
                        onExitFullScreen: widget.onExitFullScreen,
                        live: widget.live,
                        playbackSpeedListenable: _playbackSpeed,
                        onSetSpeed: _setPlaybackSpeed,
                        onEnterPipMode: _enterPipMode,
                        isPipMode: _isPipMode,
                        videoWidth: _videoWidth,
                        videoHeight: _videoHeight,
                      );
              },
            )
          : const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
    );
  }
}