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

/// 下部アンカーバナー広告（AdMob）。無料利用向け。
/// 前面ポップアップ（インタースティシャル等）は使わず、下部固定バナーのみ。
/// 将来 RevenueCat の有料エンタイトルメント保有者は false 相当にして
/// 広告非表示にする拡張余地あり（AdBannerBar 側で購読状態を見て分岐する）。
const bool kEnableAds = true;
