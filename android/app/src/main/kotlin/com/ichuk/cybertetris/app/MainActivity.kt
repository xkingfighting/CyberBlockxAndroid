package com.ichuk.cybertetris.app

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.ichuk.cybertetris/package_check"
    private val VIDEO_CHANNEL = "com.ichuk.cybertetris/video_export"
    private var videoEncoder: VideoEncoder? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Package check channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isPackageInstalled") {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    result.success(isPackageInstalled(packageName))
                } else {
                    result.error("INVALID_ARGUMENT", "packageName is required", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Video export channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIDEO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startExport" -> {
                    try {
                        val width = call.argument<Int>("width") ?: 360
                        val height = call.argument<Int>("height") ?: 640
                        val fps = call.argument<Int>("fps") ?: 30
                        val bitRate = call.argument<Int>("bitRate") ?: 2000000
                        val path = call.argument<String>("path") ?: ""
                        videoEncoder = VideoEncoder(width, height, fps, bitRate, path)
                        videoEncoder?.start()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ENCODER_ERROR", e.message, null)
                    }
                }
                "addFrame" -> {
                    try {
                        val frameData = call.argument<ByteArray>("frame")
                        if (frameData != null) {
                            videoEncoder?.addFrame(frameData)
                            result.success(true)
                        } else {
                            result.error("INVALID_FRAME", "Frame data is null", null)
                        }
                    } catch (e: Exception) {
                        result.error("ENCODE_ERROR", e.message, null)
                    }
                }
                "finishExport" -> {
                    try {
                        val path = videoEncoder?.finish() ?: ""
                        videoEncoder = null
                        result.success(path)
                    } catch (e: Exception) {
                        result.error("FINISH_ERROR", e.message, null)
                    }
                }
                "saveToGallery" -> {
                    try {
                        val path = call.argument<String>("path") ?: ""
                        val fileName = call.argument<String>("fileName") ?: "replay.mp4"
                        val ok = VideoEncoder.saveToGallery(this, path, fileName)
                        result.success(ok)
                    } catch (e: Exception) {
                        result.error("GALLERY_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }
}
