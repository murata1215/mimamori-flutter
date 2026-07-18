/// みまもりのネイティブ連携プラグイン。
///
/// 実際の Dart 側呼び出しはアプリ本体の `lib/core/native_bridge.dart` が
/// MethodChannel `mimamori/native` を通じて行う。
/// このパッケージの役割は Android 実装（[MimamoriNativePlugin]）を
/// 「宣言済み Flutter プラグイン」として提供し、MainActivity だけでなく
/// WorkManager のバックグラウンド isolate（headless FlutterEngine）にも
/// 自動登録させること。これによりアプリ未起動時のハートビートでも
/// SCREEN_ON 回数・前面アプリ利用の有無を取得できる。
library;

/// このプラグインが公開するプラットフォームチャンネル名。
/// アプリ側 `NativeBridge` と一致させること。
const String kMimamoriNativeChannel = 'mimamori/native';
