package com.example.myapp_module

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import androidx.window.layout.WindowInfoTracker
import androidx.window.layout.WindowLayoutInfo
import androidx.window.layout.FoldingFeature
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.collect

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.tiiun.foldable/window_manager"
    private val EVENT_CHANNEL = "com.tiiun.foldable/window_events"
    private var windowLayoutInfo: WindowLayoutInfo? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Method Channel 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentWindowInfo" -> {
                    getCurrentWindowInfo(result)
                }
                "startListening" -> {
                    startListening()
                    result.success(null)
                }
                "stopListening" -> {
                    // Stop listening logic can be added here
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Event Channel 설정
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    startListening()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
        
        // Start listening for window layout changes
        startListening()
    }
    
    private fun getCurrentWindowInfo(result: MethodChannel.Result) {
        val info = windowLayoutInfo
        if (info != null) {
            val foldingFeatures = info.displayFeatures.filterIsInstance<FoldingFeature>()
            val windowInfo = mapOf(
                "isFolded" to foldingFeatures.any { it.state == FoldingFeature.State.HALF_OPENED },
                "isFullyOpened" to foldingFeatures.any { it.state == FoldingFeature.State.FLAT },
                "foldingFeatureCount" to foldingFeatures.size,
                "orientation" to (foldingFeatures.firstOrNull()?.orientation?.toString() ?: "unknown")
            )
            result.success(windowInfo)
        } else {
            result.success(mapOf(
                "isFolded" to false,
                "isFullyOpened" to true,
                "foldingFeatureCount" to 0,
                "orientation" to "unknown"
            ))
        }
    }
    
    private fun startListening() {
        lifecycleScope.launch {
            WindowInfoTracker.getOrCreate(this@MainActivity)
                .windowLayoutInfo(this@MainActivity)
                .collect { layoutInfo ->
                    windowLayoutInfo = layoutInfo
                    notifyWindowLayoutChanged(layoutInfo)
                }
        }
    }
    
    private fun notifyWindowLayoutChanged(layoutInfo: WindowLayoutInfo) {
        val foldingFeatures = layoutInfo.displayFeatures.filterIsInstance<FoldingFeature>()
        val windowInfo = mapOf(
            "isFolded" to foldingFeatures.any { it.state == FoldingFeature.State.HALF_OPENED },
            "isFullyOpened" to foldingFeatures.any { it.state == FoldingFeature.State.FLAT },
            "foldingFeatureCount" to foldingFeatures.size,
            "orientation" to (foldingFeatures.firstOrNull()?.orientation?.toString() ?: "unknown")
        )
        
        // EventChannel을 통해 Flutter로 데이터 전송
        eventSink?.success(windowInfo)
        
        // 기존 MethodChannel 방식도 유지 (호환성)
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, METHOD_CHANNEL).invokeMethod("onWindowLayoutChanged", windowInfo)
        }
    }
}
