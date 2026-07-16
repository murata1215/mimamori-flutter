package com.devrelay.mimamori_flutter

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * クライアントモードのネイティブ連携を担う MethodChannel ハンドラ。
 *
 * プライバシー原則:
 *  - UsageStats からは「直近に何らかのアプリ利用があったか」の boolean のみを返す。
 *    どのアプリを・どれだけ使ったかは Flutter 側へ渡さない。
 *  - SCREEN_ON は回数のみカウントする（時刻・内容は保持しない）。
 */
class MainActivity : FlutterActivity() {

    private val channel = "mimamori/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getScreenOnCount" -> {
                        // 直近ウィンドウの SCREEN_ON 回数を取り出してリセット
                        val count = ScreenOnCounter.readAndReset(applicationContext)
                        result.success(count)
                    }
                    "hasRecentAppUsage" -> {
                        // 直近 windowMinutes 分に前面利用があったか（boolean のみ）
                        val minutes = (call.argument<Int>("windowMinutes")) ?: 15
                        result.success(hasRecentAppUsage(minutes))
                    }
                    "isUsageAccessGranted" -> result.success(isUsageAccessGranted())
                    "openUsageAccessSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(true)
                    }
                    "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                    "requestIgnoreBatteryOptimizations" -> {
                        requestIgnoreBatteryOptimizations()
                        result.success(true)
                    }
                    "openOemAutostartSettings" -> {
                        val opened = OemGuide.openAutostartSettings(this)
                        result.success(opened)
                    }
                    "getManufacturer" -> result.success(Build.MANUFACTURER ?: "")
                    "registerScreenReceiver" -> {
                        ScreenOnReceiver.register(applicationContext)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasRecentAppUsage(windowMinutes: Int): Boolean {
        if (!isUsageAccessGranted()) return false
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val start = end - windowMinutes * 60_000L
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_BEST, start, end)
        // 内容は返さず、window 内に前面利用があったか否かのみ判定
        return stats?.any { it.lastTimeUsed in start..end } ?: false
    }

    private fun isUsageAccessGranted(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (isIgnoringBatteryOptimizations()) return
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }
}
