package com.falconiptv.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val keepAliveHandler = Handler(Looper.getMainLooper())
    private var keepScreenAwake = false

    private val keepAliveTick = object : Runnable {
        override fun run() {
            if (!keepScreenAwake) {
                return
            }
            onUserInteraction()
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            window.decorView.keepScreenOn = true
            keepAliveHandler.postDelayed(this, 25_000)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "falconiptv/exoplayer")
            .setMethodCallHandler { call, result ->
                if (call.method == "bufferConfig") {
                    result.success(
                        mapOf(
                            "minBufferMs" to 15000,
                            "maxBufferMs" to 50000,
                            "bufferForPlaybackMs" to 2500,
                            "bufferForPlaybackAfterRebufferMs" to 5000,
                        ),
                    )
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "falconiptv/display")
            .setMethodCallHandler { call, result ->
                if (call.method == "setKeepScreenOn") {
                    setPlaybackKeepAwake(call.arguments as? Boolean == true)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "falconiptv/update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCacheDir" -> result.success(cacheDir.absolutePath)
                    "canInstall" -> result.success(canInstallPackages())
                    "openInstallPermission" -> {
                        openInstallPermission()
                        result.success(null)
                    }
                    "installApk" -> {
                        val path = call.arguments as? String
                        if (path.isNullOrBlank()) {
                            result.error("path", "APK yolu boş.", null)
                        } else {
                            installApk(path)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()
        if (keepScreenAwake) {
            setPlaybackKeepAwake(true)
        }
    }

    override fun onDestroy() {
        setPlaybackKeepAwake(false)
        super.onDestroy()
    }

    private fun canInstallPackages(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openInstallPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    private fun installApk(path: String) {
        val file = File(path)
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun setPlaybackKeepAwake(enabled: Boolean) {
        keepScreenAwake = enabled
        keepAliveHandler.removeCallbacks(keepAliveTick)
        if (enabled) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            window.decorView.keepScreenOn = true
            onUserInteraction()
            keepAliveHandler.post(keepAliveTick)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            window.decorView.keepScreenOn = false
        }
    }
}
