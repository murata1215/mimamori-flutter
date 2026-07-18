import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'api/http_api_client.dart';
import 'api/mock_api_client.dart';
import 'config.dart';
import 'storage/prefs.dart';

/// Prefs は起動時に override して注入する。
final prefsProvider = Provider<Prefs>((ref) {
  throw UnimplementedError('prefsProvider must be overridden in main()');
});

/// API クライアントを生成する。モードに応じて Mock / HTTP を切り替える。
/// HTTP 版は Prefs を受け取り、401 時のトークン自動リフレッシュに使う。
ApiClient createApiClient(Prefs prefs) {
  if (AppConfig.isMockActive) {
    return MockApiClient();
  }
  return HttpApiClient(AppConfig.apiBaseUrl, prefs: prefs);
}

/// API クライアント。モードに応じて Mock / HTTP を切り替える。
/// main() で単一インスタンスを override する（FcmService と共有するため）。
final apiClientProvider = Provider<ApiClient>((ref) {
  return createApiClient(ref.watch(prefsProvider));
});

/// 現在のアクティブロール。
final activeRoleProvider = StateProvider<AppRole?>((ref) {
  return ref.watch(prefsProvider).activeRole;
});
