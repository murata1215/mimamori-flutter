import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/watched_client.dart';
import '../core/providers.dart';

/// ウォッチャーが見守るクライアント一覧。
/// プライバシー原則: サーバーは status と status_changed_at のみ返す。
final watchedClientsProvider =
    FutureProvider.autoDispose<List<WatchedClient>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final prefs = ref.watch(prefsProvider);
  final token = prefs.watcherToken ?? 'mock-watcher-token';
  return api.listClients(watcherToken: token);
});

/// クライアントのステータス遷移履歴（粒度は遷移のみ）。
final statusHistoryProvider = FutureProvider.autoDispose
    .family<List<StatusTransition>, String>((ref, clientId) async {
  final api = ref.watch(apiClientProvider);
  final prefs = ref.watch(prefsProvider);
  final token = prefs.watcherToken ?? 'mock-watcher-token';
  return api.statusHistory(watcherToken: token, clientId: clientId);
});
