/// 機能の表示フラグ。Phase 1 では UI をシンプルに保つため一部機能を隠す。
///
/// バックエンド連携・サービス層（API・モデル・SOSService・通知処理など）は
/// 温存しているため、フラグを true に戻すだけで UI を再表示できる。
library;

/// きもち（スタンプ）の送受信 UI。
/// クライアントホームの StampSection / ウォッチャー詳細の _StampPanel を制御する。
const bool kEnableStamps = false;

/// クライアント側の SOS 発信 UI。
/// ホームの SOS 大ボタン（SosButton）を制御する。
/// Android ホームウィジェットは AndroidManifest 側で無効化する。
const bool kEnableSosSend = false;
