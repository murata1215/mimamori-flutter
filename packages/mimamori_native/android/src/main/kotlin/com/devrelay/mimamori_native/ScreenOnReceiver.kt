package com.devrelay.mimamori_native

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter

/**
 * ACTION_SCREEN_ON を受けて回数をカウントする。
 * 画面点灯は「本人が端末に触れている」生存シグナルの近似。
 *
 * SCREEN_ON はマニフェスト宣言では受信できないため、
 * プロセス生存中は動的登録する（プラグイン attach 時 / BOOT_COMPLETED 時）。
 */
class ScreenOnReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_SCREEN_ON) {
            ScreenOnCounter.increment(context.applicationContext)
        }
    }

    companion object {
        @Volatile
        private var registered = false
        private val instance = ScreenOnReceiver()

        fun register(context: Context) {
            if (registered) return
            val filter = IntentFilter(Intent.ACTION_SCREEN_ON)
            context.applicationContext.registerReceiver(instance, filter)
            registered = true
        }
    }
}
