import 'dart:io';

/// AdMob の各種 ID 設定。
///
/// 既定値は **Google 公式のテスト ID**（「Test Ad」ラベル付きで表示される安全な ID）。
/// 本番公開前に AdMob で発行したアプリ ID / バナーユニット ID を投入すること。
/// テスト ID のままストア公開すると AdMob ポリシー違反になるため必須。
///
/// 本番 ID はビルド時に上書きできる:
///   flutter build apk \
///     --dart-define=ADMOB_APP_ID_ANDROID=ca-app-pub-XXXX~YYYY \
///     --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-XXXX/ZZZZ
class AdConfig {
  AdConfig._();

  // --- Google 公式テスト ID（差し替え前の既定値） ---
  static const _testAppIdAndroid = 'ca-app-pub-3940256099942544~3347511713';
  static const _testAppIdIos = 'ca-app-pub-3940256099942544~1458002511';
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';

  // --- dart-define による本番 ID 上書き（未指定なら空文字） ---
  static const _envAppIdAndroid =
      String.fromEnvironment('ADMOB_APP_ID_ANDROID', defaultValue: '');
  static const _envAppIdIos =
      String.fromEnvironment('ADMOB_APP_ID_IOS', defaultValue: '');
  static const _envBannerAndroid =
      String.fromEnvironment('ADMOB_BANNER_ANDROID', defaultValue: '');
  static const _envBannerIos =
      String.fromEnvironment('ADMOB_BANNER_IOS', defaultValue: '');

  /// 実行プラットフォームのバナーユニット ID。
  static String get bannerUnitId {
    if (Platform.isIOS) {
      return _envBannerIos.isNotEmpty ? _envBannerIos : _testBannerIos;
    }
    return _envBannerAndroid.isNotEmpty ? _envBannerAndroid : _testBannerAndroid;
  }

  /// 実行プラットフォームのアプリ ID（参考用。実際の適用は Manifest / Info.plist 側）。
  static String get appId {
    if (Platform.isIOS) {
      return _envAppIdIos.isNotEmpty ? _envAppIdIos : _testAppIdIos;
    }
    return _envAppIdAndroid.isNotEmpty ? _envAppIdAndroid : _testAppIdAndroid;
  }

  /// 本番 ID が投入済みか（テスト ID のままかの判定）。
  static bool get isUsingTestIds {
    if (Platform.isIOS) return _envBannerIos.isEmpty;
    return _envBannerAndroid.isEmpty;
  }
}
