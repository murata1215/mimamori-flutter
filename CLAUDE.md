# mimamori-flutter

見守りアプリ「みまもり」の Flutter クライアント（Phase 1 MVP）。
単一アプリ・2ロール構成（クライアント=見守られる側 / ウォッチャー=見守る側）。Android 優先。

## 技術スタック
- **フレームワーク**: Flutter / **言語**: Dart
- **状態管理**: Riverpod (`flutter_riverpod`)
- **HTTP**: dio（`ApiClient` 抽象 → `HttpApiClient` / `MockApiClient` 切替）
- **バックグラウンド**: workmanager（15分周期ハートビート）
- **ネイティブ連携**: ローカルプラグイン `packages/mimamori_native`（MethodChannel `mimamori/native`、Kotlin: UsageStats・SCREEN_ON・電池最適化除外・OEMガイド）。**プラグイン化により WorkManager のバックグラウンド isolate にも自動登録され、アプリ未起動時のハートビートでも生存イベント（画面点灯回数・前面アプリ利用）を取得できる**（旧: MainActivity 直登録だとバックグラウンドで常に 0/false になるバグがあった）
- **プッシュ通知**: FCM（`firebase_messaging`）+ `flutter_local_notifications`（全画面インテント通知）
- **位置情報**: geolocator（SOS時のみ単発取得）
- **課金**: RevenueCat（`purchases_flutter`、キー投入まではスタブ）
- **広告**: AdMob（`google_mobile_ads`、無料利用向け下部アンカーバナーのみ。前面ポップアップは使わない。既定は公式テストID、本番IDは `--dart-define` で投入）
- **フォント**: M PLUS Rounded 1c（丸ゴシック、`assets/fonts/` に同梱・`theme.dart` で全体適用。端末依存の明朝フォールバック回避）
- **その他**: mobile_scanner/qr_flutter（ペアリング）、home_widget（SOSウィジェット）、shared_preferences、battery_plus、device_info_plus、url_launcher、permission_handler

## フィーチャーフラグ（`lib/core/feature_flags.dart`）
- `kEnableStamps=true`（きもち＝スタンプ送受信UI。本人に「使う理由」を与え、能動的な生存イベントのシグナル源にもなるため有効化）
- `kEnableSosSend=false`（SOS発信UIは隠すがサービス層は温存、true で復活）
- `kEnableAds=true`（下部バナー広告。**表示はウォッチャー側のみ**。見守られる本人＝高齢者には出さない）
- `kEnableFreeWatchLimit`（無料枠2人制限＋ペイウォール。テスト中は false で無効化。**リリース前に true へ戻す**。サーバー側の 402 制限は watcher.plan で別途制御）

## 設計原則
- 端末は生存シグナル（ハートビート）を送るだけ。異常判定はサーバー側（デッドマンスイッチ）
- プライバシー最小開示: ウォッチャーには4段階ステータス＋最終操作時刻・最終通信時刻（時刻のみ・15分粒度、server: `last_activity_at`/`last_seen_at`）。位置情報は SOS 時のみ。アプリ名・操作内容など「何をしたか」は送らない（生存確認の中核として「いつ操作したか」は開示するが、内容は非開示）
- クライアントモードは高齢者向けUI（最小16sp、大ボタン、少ない画面数）

## 開発コマンド
```bash
flutter run          # デバッグ実行（既定で本番サーバー https://mimamori-server.devrelay.io に接続）
flutter run --dart-define=USE_MOCK=true            # モックモード（サーバー未接続で全画面確認）
flutter run --dart-define=API_BASE_URL=https://... # 接続先サーバーを上書き（既定は本番URL）
flutter build apk    # Android APK ビルド
flutter test         # テスト実行
flutter analyze      # 静的解析
```

## セットアップ注意
- **FCM**: Firebase プロジェクト `mimamori-92060`（package `com.devrelay.mimamori_flutter`）作成済み。`android/app/google-services.json` を配置すると自動で有効化（gitignore 対象・未配置でも起動可）。起動時に FCM トークンを `PUT /v1/devices/me/fcm-token`（watcher は `/v1/watchers/me/fcm-token`）へ自動登録。サーバー送信は実装済みで、Admin SDK 秘密鍵を `.env` の `FIREBASE_CREDENTIALS_PATH` で投入して有効化する
- **RevenueCat**: API キー投入までは購入処理はスタブ
- **minSdk**: 26（Android 8.0以上）
