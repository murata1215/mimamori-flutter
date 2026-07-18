# mimamori-flutter

見守りアプリ「みまもり」の Flutter クライアント（Phase 1 MVP）。
単一アプリ・2ロール構成（クライアント=見守られる側 / ウォッチャー=見守る側）。Android 優先。

## 技術スタック
- **フレームワーク**: Flutter / **言語**: Dart
- **状態管理**: Riverpod (`flutter_riverpod`)
- **HTTP**: dio（`ApiClient` 抽象 → `HttpApiClient` / `MockApiClient` 切替）
- **バックグラウンド**: workmanager（15分周期ハートビート）
- **ネイティブ連携**: MethodChannel（Kotlin: UsageStats・SCREEN_ON・電池最適化除外・OEMガイド）
- **プッシュ通知**: FCM（`firebase_messaging`）+ `flutter_local_notifications`（全画面インテント通知）
- **位置情報**: geolocator（SOS時のみ単発取得）
- **課金**: RevenueCat（`purchases_flutter`、キー投入まではスタブ）
- **その他**: mobile_scanner/qr_flutter（ペアリング）、home_widget（SOSウィジェット）、shared_preferences、battery_plus、device_info_plus、url_launcher、permission_handler

## 設計原則
- 端末は生存シグナル（ハートビート）を送るだけ。異常判定はサーバー側（デッドマンスイッチ）
- プライバシー最小開示: ウォッチャーには4段階ステータスのみ。位置情報は SOS 時のみ。アプリ名・利用詳細は送らない
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
- **FCM**: `android/app/google-services.json` を配置すると自動で有効化（未配置でも起動可）
- **RevenueCat**: API キー投入までは購入処理はスタブ
- **minSdk**: 26（Android 8.0以上）
