# みまもり (mimamori-flutter)

事故物件認定につながる孤独死を一件でも減らすための見守りアプリ、その Flutter クライアント（**Phase 1 MVP**）。

独居者の異常を早期に検知し、発見の遅れを防ぐ。単一アプリに「クライアントモード（見守られる側）」と「ウォッチャーモード（見守る側）」を持つ。

## コア思想

- **端末は判定しない**: 端末は生存シグナル（ハートビート）を送るだけ。異常判定はサーバー側で行う（デッドマンスイッチはサーバー側判定）
- **プライバシー最小開示**: ウォッチャーに見えるのは「生存 / 注視 / 警告 / SOS」の4段階ステータスのみ。位置情報が送られるのは本人が SOS ボタンを押した時だけ
- **高齢者向けUI**: 大きな文字（最小16sp）・大きなボタン・少ない画面数。「一度設定したら二度と触らない」を理想とする

## 主な機能

### クライアントモード（見守られる側 / Android）
- 同意フロー（スキップ不可・図解付き）
- ペアリング（QRスキャン / 6桁コード入力）
- 権限設定ウィザード（通知・UsageStats・電池最適化除外・OEM別タスクキラー対策・位置情報）
- ハートビート送信（WorkManager 15分周期 + ネイティブ収集、送信失敗時はキュー再送）
- SOSボタン（長押し3秒 → 10秒取消カウントダウン → GPS単発取得・SMSフォールバック）+ ホームウィジェット
- 本人確認（全画面インテント通知、タップ1回で復帰）
- 権限ヘルスチェック

### ウォッチャーモード（見守る側 / Android・iOS）
- クライアント一覧（5色バッジ + 名前のみ表示 = 最小開示）
- ステータス遷移履歴・通知設定
- クライアント追加（QR/6桁コード発行、3人目からペイウォール）
- 通知受信（注視=通常 / 警告=全画面+アラーム / SOS=地図直行 / 設定に問題）
- オーナーダッシュボード骨格（有料プラン）

## 技術スタック

Flutter / Dart / Riverpod / dio / workmanager / MethodChannel(Kotlin) / FCM + flutter_local_notifications / geolocator / mobile_scanner / home_widget / RevenueCat(スタブ) ほか。詳細は `CLAUDE.md` を参照。

## セットアップ

```bash
flutter pub get

# サーバー未接続でも全画面を確認できるモックモード
flutter run --dart-define=USE_MOCK=true

# 実サーバーに接続
flutter run --dart-define=API_BASE_URL=https://your-server.example.com
```

### FCM（プッシュ通知）を有効化する

1. Firebase Console でプロジェクト作成 → Android アプリ登録（パッケージ名 `com.devrelay.mimamori_flutter`）
2. `google-services.json` をダウンロードして `android/app/` に配置
3. `flutter run` し直すだけで有効になる（未配置でもアプリは起動します）

### 課金（RevenueCat）

API キーを投入するまで購入処理はスタブで動作します。

## 動作要件

- Android 8.0（API 26）以上（クライアントモード）
- iOS はウォッチャーモードのみ先行対応

## ビルド確認

```bash
flutter analyze     # 静的解析
flutter test        # テスト
flutter build apk   # Android APK
```

## ステータス

Phase 1（スマホのみ・個人向け）実装済み。サーバー実装・Firebase/RevenueCat 本番キー投入後に結合テスト予定。
