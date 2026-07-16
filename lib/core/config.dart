/// アプリ全体の設定値。ビルド時に --dart-define で上書き可能。
class AppConfig {
  /// API のベース URL。未指定時は空（モックモードを推奨）。
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// モックモード。サーバー未接続でも全画面を動作確認できる。
  /// 例: flutter run --dart-define=USE_MOCK=true
  ///
  /// デフォルトは false。API_BASE_URL 未指定時は下の isMockActive が
  /// 自動的にモックへフォールバックするため、URL を指定するだけで実サーバー接続になる。
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: false,
  );

  /// モックモードが有効か（明示指定 or サーバーURL未設定）。
  static bool get isMockActive => useMock || apiBaseUrl.isEmpty;

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
