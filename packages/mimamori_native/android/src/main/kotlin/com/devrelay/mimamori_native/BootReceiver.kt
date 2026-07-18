package com.devrelay.mimamori_native

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 端末再起動後に SCREEN_ON レシーバを再登録する。
 * WorkManager の定期タスクは OS が自動復帰させるが、
 * 動的登録のレシーバは明示的に再登録が必要。
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            ScreenOnReceiver.register(context.applicationContext)
        }
    }
}
