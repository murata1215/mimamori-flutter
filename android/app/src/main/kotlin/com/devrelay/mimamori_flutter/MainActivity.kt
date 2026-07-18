package com.devrelay.mimamori_flutter

import io.flutter.embedding.android.FlutterActivity

/**
 * みまもりのメイン Activity。
 *
 * ネイティブ連携（MethodChannel `mimamori/native`）は
 * ローカルプラグイン `mimamori_native`（[com.devrelay.mimamori_native.MimamoriNativePlugin]）
 * へ移設した。プラグイン化により MainActivity の FlutterEngine だけでなく
 * WorkManager のバックグラウンド isolate にも自動登録され、
 * アプリ未起動時のハートビートでも生存イベントを取得できる。
 */
class MainActivity : FlutterActivity()
