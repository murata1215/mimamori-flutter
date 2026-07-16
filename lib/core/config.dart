/// アプリ全体の設定値。ビルド時に --dart-define で上書き可能。
class AppConfig {
  /// API のベース URL。未指定時は空（モックモードを推奨）。
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// モックモード。サーバー未接続でも全画面を動作確認できる。
  /// 例: flutter run --dart-define=USE_MOCK=true
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: true,
  );

  /// 同意文言のバージョン（サーバーへ consent_version として記録）。
  static const String consentVersion = 'v1.0';

  /// RevenueCat API キー（未設定ならペイウォールはスタブ動作）。
  static const String revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_KEY',
    defaultValue: '',
  );

  /// ウォッチャー1人あたりの月額（3人目以降）。表示用。
  static const int perClientYen = 100;
}
