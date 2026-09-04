package com.falconiptv.app

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Base64
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val keepAliveHandler = Handler(Looper.getMainLooper())
    private var keepScreenAwake = false
    private var sportMode = false

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
                when (call.method) {
                    "setSportMode" -> {
                        sportMode = call.arguments as? Boolean == true
                        result.success(null)
                    }
                    "bufferConfig" -> {
                        result.success(
                            if (sportMode) {
                                mapOf(
                                    "minBufferMs" to 30000,
                                    "maxBufferMs" to 70000,
                                    "bufferForPlaybackMs" to 8000,
                                    "bufferForPlaybackAfterRebufferMs" to 12000,
                                )
                            } else {
                                mapOf(
                                    "minBufferMs" to 15000,
                                    "maxBufferMs" to 50000,
                                    "bufferForPlaybackMs" to 2000,
                                    "bufferForPlaybackAfterRebufferMs" to 5000,
                                )
                            },
                        )
                    }
                    else -> result.notImplemented()
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "falconiptv/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deviceProfile" -> result.success(deviceProfile())
                    "isTelevision" -> result.success(deviceProfile()["isTelevision"])
                    else -> result.notImplemented()
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
                    "canInstallOverCurrent" -> {
                        val path = call.arguments as? String
                        result.success(canInstallOverCurrent(path))
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

    private fun deviceProfile(): Map<String, Any> {
        val pm = packageManager
        val uiType = resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK
        val leanback = pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
        val leanbackOnly = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK_ONLY)
        @Suppress("DEPRECATION")
        val television = pm.hasSystemFeature(PackageManager.FEATURE_TELEVISION)
        val uiTelevision = uiType == Configuration.UI_MODE_TYPE_TELEVISION
        val fireTv = pm.hasSystemFeature("amazon.hardware.fire_tv")
        val watch = pm.hasSystemFeature(PackageManager.FEATURE_WATCH)
        val automotive = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            pm.hasSystemFeature(PackageManager.FEATURE_AUTOMOTIVE)
        val isTelevision = !watch && !automotive &&
            (leanback || leanbackOnly || television || uiTelevision || fireTv)
        return mapOf(
            "isTelevision" to isTelevision,
            "leanback" to leanback,
            "leanbackOnly" to leanbackOnly,
            "televisionFeature" to television,
            "uiModeTelevision" to uiTelevision,
            "fireTv" to fireTv,
            "watch" to watch,
            "automotive" to automotive,
        )
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

    private fun canInstallOverCurrent(path: String?): Boolean {
        if (path.isNullOrBlank()) {
            return false
        }
        val incoming = archiveSignatures(path) ?: return false
        val installed = installedSignatures() ?: return true
        return incoming.isNotEmpty() && installed.isNotEmpty() && incoming.intersect(installed).isNotEmpty()
    }

    private fun installedSignatures(): Set<String>? {
        return try {
            signaturesOf(installedPackageInfo() ?: return null)
        } catch (_: Exception) {
            null
        }
    }

    private fun archiveSignatures(path: String): Set<String>? {
        return try {
            val info = archivePackageInfo(path) ?: return null
            signaturesOf(info)
        } catch (_: Exception) {
            null
        }
    }

    private fun installedPackageInfo(): PackageInfo? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.PackageInfoFlags.of(signingFlags().toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, signingFlags())
        }
    }

    private fun archivePackageInfo(path: String): PackageInfo? {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageArchiveInfo(
                path,
                PackageManager.PackageInfoFlags.of(signingFlags().toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageArchiveInfo(path, signingFlags())
        }
        info?.applicationInfo?.apply {
            sourceDir = path
            publicSourceDir = path
        }
        return info
    }

    private fun signingFlags(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }
    }

    private fun signaturesOf(info: PackageInfo): Set<String> {
        val bytes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = info.signingInfo ?: return emptySet()
            val signers = if (signingInfo.hasMultipleSigners()) {
                signingInfo.apkContentsSigners
            } else {
                signingInfo.signingCertificateHistory
            }
            signers
        } else {
            @Suppress("DEPRECATION")
            info.signatures
        }
        return bytes
            ?.map { Base64.encodeToString(it.toByteArray(), Base64.NO_WRAP) }
            ?.toSet()
            ?: emptySet()
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
