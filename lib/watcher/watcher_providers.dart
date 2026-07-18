import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/daily_activity.dart';
import '../core/models/stamp.dart';
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

/// 指定クライアントとの双方向スタンプ履歴（新しい順）。
final stampHistoryProvider = FutureProvider.autoDispose
    .family<List<Stamp>, String>((ref, clientId) async {
  final api = ref.watch(apiClientProvider);
  final prefs = ref.watch(prefsProvider);
  final token = prefs.watcherToken ?? 'mock-watcher-token';
  return api.listClientStamps(watcherToken: token, clientId: clientId);
});

/// 指定クライアントの過去3日間の活動量（新しい日→古い日）。
final clientActivityProvider = FutureProvider.autoDispose
    .family<List<DailyActivity>, String>((ref, clientId) async {
  final api = ref.watch(apiClientProvider);
  final prefs = ref.watch(prefsProvider);
  final token = prefs.watcherToken ?? 'mock-watcher-token';
  return api.getClientActivity(
      watcherToken: token, clientId: clientId, days: 3);
});
