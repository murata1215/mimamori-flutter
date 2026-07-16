package com.devrelay.mimamori_flutter

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * OEM (Xiaomi/OPPO/Huawei/vivo 等) のタスクキラー対策。
 * 各社の自動起動 / 電池管理設定画面を可能な限り直接開く。
 * dontkillmyapp.com 相当の内容。開けなければ false を返し、
 * Flutter 側で手動手順を表示させる。
 */
object OemGuide {

    private val intents = listOf(
        // Xiaomi (MIUI)
        ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
        // OPPO / realme (ColorOS)
        ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
        ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
        ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
        // vivo (FuntouchOS)
        ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
        ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
        // Huawei (EMUI)
        ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
        ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
        // Samsung
        ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity"),
        // Letv / Meizu / Asus 等はブランド判定困難のため省略（手動導線でカバー）
    )

    fun openAutostartSettings(context: Context): Boolean {
        for (component in intents) {
            try {
                val intent = Intent().apply {
                    setComponent(component)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                return true
            } catch (_: Exception) {
                // 次の候補へ
            }
        }
        return false
    }

    fun manufacturer(): String = (Build.MANUFACTURER ?: "").lowercase()
}
