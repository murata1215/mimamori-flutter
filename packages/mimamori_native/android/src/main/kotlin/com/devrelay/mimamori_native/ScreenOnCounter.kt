package com.devrelay.mimamori_native

import android.content.Context

/**
 * SCREEN_ON の回数のみを保持する軽量カウンタ。
 * 時刻や内容は一切保存しない（プライバシー原則）。
 */
object ScreenOnCounter {
    private const val PREFS = "mimamori_screen"
    private const val KEY_COUNT = "screen_on_count"

    fun increment(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val current = prefs.getInt(KEY_COUNT, 0)
        prefs.edit().putInt(KEY_COUNT, current + 1).apply()
    }

    /** 現在のカウントを読み取り 0 にリセットして返す（ハートビート送信時に消費）。 */
    fun readAndReset(context: Context): Int {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val count = prefs.getInt(KEY_COUNT, 0)
        prefs.edit().putInt(KEY_COUNT, 0).apply()
        return count
    }
}
