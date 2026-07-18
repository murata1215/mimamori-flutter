package com.devrelay.mimamori_native

import android.app.Activity
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * みまもりのネイティブ連携を担う Flutter プラグイン。
 *
 * 従来 MainActivity に実装していた MethodChannel ハンドラをプラグイン化した。
 * 「宣言済みプラグイン」は MainActivity の FlutterEngine だけでなく
 * WorkManager が生成するバックグラウンド isolate の FlutterEngine にも
 * 自動登録されるため、アプリ未起動時のハートビートでも
 * 生存イベント（SCREEN_ON 回数・前面アプリ利用の有無）を取得できる。
 *
 * プライバシー原則:
 *  - UsageStats からは「直近に何らかのアプリ利用があったか」の boolean のみを返す。
 *    どのアプリを・どれだけ使ったかは Flutter 側へ渡さない。
 *  - SCREEN_ON は回数のみカウントする（時刻・内容は保持しない）。
 */
class MimamoriNativePlugin :
    FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "mimamori/native")
        channel.setMethodCallHandler(this)
        // エンジン起動（＝プロセス起床）ごとに SCREEN_ON レシーバを自己回復登録する。
        // WorkManager が15分ごとに isolate を起こすたびに再登録されるため、
        // OEM のタスクキラーにプロセスを殺されても最大15分で復帰する。
        ScreenOnReceiver.register(appContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getScreenOnCount" -> {
                // 直近ウィンドウの SCREEN_ON 回数を取り出してリセット
                result.success(ScreenOnCounter.readAndReset(appContext))
            }
            "hasRecentAppUsage" -> {
                // 直近 windowMinutes 分に前面利用があったか（boolean のみ）
                val minutes = call.argument<Int>("windowMinutes") ?: 15
                result.success(hasRecentAppUsage(minutes))
            }
            "isUsageAccessGranted" -> result.success(isUsageAccessGranted())
            "openUsageAccessSettings" -> {
                val act = activity
                if (act == null) {
                    result.success(false)
                } else {
                    act.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(true)
                }
            }
            "isIgnoringBatteryOptimizations" ->
                result.success(isIgnoringBatteryOptimizations())
            "requestIgnoreBatteryOptimizations" ->
                result.success(requestIgnoreBatteryOptimizations())
            "openOemAutostartSettings" -> {
                val act = activity
                if (act == null) {
                    result.success(false)
                } else {
                    result.success(OemGuide.openAutostartSettings(act))
                }
            }
            "getManufacturer" -> result.success(Build.MANUFACTURER ?: "")
            "registerScreenReceiver" -> {
                ScreenOnReceiver.register(appContext)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    // --- ActivityAware（設定画面を開く系は Activity が必要） ---

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // --- 実処理 ---

    private fun hasRecentAppUsage(windowMinutes: Int): Boolean {
        if (!isUsageAccessGranted()) return false
        val usm =
            appContext.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val start = end - windowMinutes * 60_000L
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_BEST, start, end)
        // 内容は返さず、window 内に前面利用があったか否かのみ判定
        return stats?.any { it.lastTimeUsed in start..end } ?: false
    }

    private fun isUsageAccessGranted(): Boolean {
        val appOps =
            appContext.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                appContext.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                appContext.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val pm = appContext.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(appContext.packageName)
    }

    /** 電池最適化除外を要求する。Activity が無い（バックグラウンド）場合は何もせず false。 */
    private fun requestIgnoreBatteryOptimizations(): Boolean {
        if (isIgnoringBatteryOptimizations()) return true
        val act = activity ?: return false
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:${appContext.packageName}")
        }
        act.startActivity(intent)
        return true
    }
}
