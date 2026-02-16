package com.vidora.app

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.graphics.Rect
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.vidora.app/pip"
    private var methodChannel: MethodChannel? = null
    private var isPipMode = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPipMode" -> {
                    val aspectRatioX = call.argument<Int>("aspectRatioX") ?: 16
                    val aspectRatioY = call.argument<Int>("aspectRatioY") ?: 9
                    val sourceLeft = call.argument<Int>("sourceLeft")
                    val sourceTop = call.argument<Int>("sourceTop")
                    val sourceRight = call.argument<Int>("sourceRight")
                    val sourceBottom = call.argument<Int>("sourceBottom")
                    
                    var sourceRect: Rect? = null
                    if (sourceLeft != null && sourceTop != null && 
                        sourceRight != null && sourceBottom != null) {
                        sourceRect = Rect(sourceLeft, sourceTop, sourceRight, sourceBottom)
                    }
                    
                    val success = enterPipMode(aspectRatioX, aspectRatioY, sourceRect)
                    result.success(success)
                }
                "isPipMode" -> {
                    result.success(isPipMode)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun enterPipMode(aspectRatioX: Int, aspectRatioY: Int, sourceRect: Rect?): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                // 创建宽高比，确保在有效范围内 (1/2.39 到 2.39/1)
                var rational = Rational(aspectRatioX, aspectRatioY)
                if (rational.toFloat() > 2.39f) {
                    rational = Rational(239, 100)
                } else if (rational.toFloat() < 0.418f) {
                    rational = Rational(100, 239)
                }
                
                val builder = PictureInPictureParams.Builder()
                    .setAspectRatio(rational)
                
                // 设置源矩形区域，告诉系统 PiP 窗口应该截取屏幕的哪个区域
                // 这在 Android 8.0+ 都有效，但效果因系统版本和设备而异
                if (sourceRect != null) {
                    builder.setSourceRectHint(sourceRect)
                }
                
                enterPictureInPictureMode(builder.build())
                return true
            } catch (e: Exception) {
                e.printStackTrace()
                return false
            }
        }
        return false
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        
        isPipMode = isInPictureInPictureMode
        
        // 通知 Flutter 端 PiP 状态变化
        methodChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // 用户按 Home 键时，如果播放器处于播放状态，可以自动进入 PiP
        // 这里由 Flutter 端控制是否自动进入，所以不在这里处理
    }
}