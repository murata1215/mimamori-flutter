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

/// API クライアント。モードに応じて Mock / HTTP を切り替える。
final apiClientProvider = Provider<ApiClient>((ref) {
  if (AppConfig.isMockActive) {
    return MockApiClient();
  }
  return HttpApiClient(AppConfig.apiBaseUrl);
});

/// 現在のアクティブロール。
final activeRoleProvider = StateProvider<AppRole?>((ref) {
  return ref.watch(prefsProvider).activeRole;
});
