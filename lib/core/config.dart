/// アプリ全体の設定値。ビルド時に --dart-define で上書き可能。
class AppConfig {
  /// API のベース URL。本番サーバーを既定値として固定する。
  /// `flutter run` だけで実サーバー接続になる。
  /// 別サーバーへ向けたい場合のみ `--dart-define=API_BASE_URL=...` で上書き可能。
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mimamori-server.devrelay.io',
  );

  /// モックモード。サーバー未接続でも全画面を動作確認できる。
  /// 明示指定したときのみ有効: flutter run --dart-define=USE_MOCK=true
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: false,
  );

  /// モックモードが有効か（USE_MOCK 明示指定 or サーバーURL未設定）。
  /// apiBaseUrl は既定で本番URLが入るため、通常は useMock のみで判定される。
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
