package com.network.proxy.plugin

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.network.proxy.FloatingWindowService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter 与悬浮窗服务的桥接
 */
class FloatingWindowPlugin : AndroidFlutterPlugin() {

    companion object {
        const val CHANNEL = "com.proxy/floating"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "canDrawOverlays" -> {
                    result.success(Settings.canDrawOverlays(activity))
                }

                "openOverlaySettings" -> {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:${activity.packageName}")
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    activity.startActivity(intent)
                    result.success(null)
                }

                "startFloating" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(activity)) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val isRunning = call.argument<Boolean>("isRunning") ?: false
                    val intent = Intent(activity, FloatingWindowService::class.java).apply {
                        putExtra(FloatingWindowService.EXTRA_RUNNING, isRunning)
                    }
                    activity.startService(intent)
                    result.success(true)
                }

                "stopFloating" -> {
                    activity.stopService(Intent(activity, FloatingWindowService::class.java))
                    result.success(null)
                }

                "updateState" -> {
                    val isRunning = call.argument<Boolean>("isRunning") ?: false
                    FloatingWindowService.updateState(isRunning)
                    result.success(null)
                }

                "isFloating" -> {
                    result.success(FloatingWindowService.isShowing)
                }

                else -> result.notImplemented()
            }
        }
    }
}
