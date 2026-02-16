import 'dart:async';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// PiP 服务类
/// 处理 Android 原生 PiP 功能的 Flutter 端逻辑
class PipService {
  static const MethodChannel _channel = MethodChannel('com.vidora.app/pip');
  static final PipService _instance = PipService._internal();
  factory PipService() => _instance;
  PipService._internal();

  bool _isPipMode = false;
  bool _isInitialized = false;
  final StreamController<bool> _pipModeController = StreamController<bool>.broadcast();

  /// PiP 模式状态变化流
  Stream<bool> get onPipModeChanged => _pipModeController.stream;

  /// 当前是否处于 PiP 模式
  bool get isPipMode => _isPipMode;

  /// 初始化服务
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    if (Platform.isAndroid) {
      _channel.setMethodCallHandler(_handleMethodCall);
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPipModeChanged':
        final isInPipMode = call.arguments as bool;
        _isPipMode = isInPipMode;
        _pipModeController.add(isInPipMode);
        debugPrint('PiP mode changed: $isInPipMode');
        return null;
      default:
        return null;
    }
  }

  /// 进入 PiP 模式
  /// [aspectRatioX] 宽高比的宽
  /// [aspectRatioY] 宽高比的高
  /// [sourceRect] 可选，指定要显示在 PiP 窗口中的源区域
  Future<bool> enterPipMode({
    int aspectRatioX = 16,
    int aspectRatioY = 9,
    Rect? sourceRect,
  }) async {
    if (!Platform.isAndroid) {
      debugPrint('PiP is only supported on Android');
      return false;
    }

    try {
      final args = <String, dynamic>{
        'aspectRatioX': aspectRatioX,
        'aspectRatioY': aspectRatioY,
      };
      
      // 添加源矩形区域参数
      // 这个矩形定义了 PiP 窗口应该显示屏幕的哪个区域
      // 在 Android 8.0+ 上都有效，但在 Android 12+ 上效果最佳
      if (sourceRect != null) {
        args['sourceLeft'] = sourceRect.left.toInt();
        args['sourceTop'] = sourceRect.top.toInt();
        args['sourceRight'] = sourceRect.right.toInt();
        args['sourceBottom'] = sourceRect.bottom.toInt();
      }
      
      final result = await _channel.invokeMethod<bool>('enterPipMode', args);
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to enter PiP mode: $e');
      return false;
    }
  }

  /// 检查当前是否处于 PiP 模式
  Future<bool> checkPipMode() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('isPipMode');
      _isPipMode = result ?? false;
      return _isPipMode;
    } catch (e) {
      debugPrint('Failed to check PiP mode: $e');
      return false;
    }
  }

  /// 释放资源
  void dispose() {
    _pipModeController.close();
    _isInitialized = false;
  }
}
