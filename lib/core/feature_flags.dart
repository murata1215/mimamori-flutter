/// 機能の表示フラグ。Phase 1 では UI をシンプルに保つため一部機能を隠す。
///
/// バックエンド連携・サービス層（API・モデル・SOSService・通知処理など）は
/// 温存しているため、フラグを true に戻すだけで UI を再表示できる。
library;

/// きもち（スタンプ）の送受信 UI。
/// クライアントホームの StampSection / ウォッチャー詳細の _StampPanel を制御する。
///
/// 有効化理由（外部レビュー2件の一致指摘）:
/// 見守られる本人にも「使う理由」を与えるリテンション装置であり、
/// 同時に本人の能動的な生存イベント（きもち送信）というシグナル源にもなる。
const bool kEnableStamps = true;

/// クライアント側の SOS 発信 UI。
/// ホームの SOS 大ボタン（SosButton）を制御する。
/// Android ホームウィジェットは AndroidManifest 側で無効化する。
const bool kEnableSosSend = false;

/// 下部アンカーバナー広告（AdMob）。無料利用向け。
/// 前面ポップアップ（インタースティシャル等）は使わず、下部固定バナーのみ。
/// 表示対象はウォッチャー側（WatcherShell）のみに限定する。
/// クライアント（見守られる本人・無償協力者・誤タップの多い高齢者）には表示しない。
/// 将来 RevenueCat の有料エンタイトルメント保有者は false 相当にして
/// 広告非表示にする拡張余地あり（AdBannerBar 側で購読状態を見て分岐する）。
const bool kEnableAds = true;

/// 無料枠の見守り人数制限（2人）とペイウォール表示。
/// テスト中は false で無効化（3人以上を登録可能にする）。
/// サーバー側の 402 制限も別途 watcher.plan を owner にして無効化する必要あり。
/// TODO: 課金テスト・リリース前に true へ戻す（併せてサーバーの plan も free に戻す）。
const bool kEnableFreeWatchLimit = false;
