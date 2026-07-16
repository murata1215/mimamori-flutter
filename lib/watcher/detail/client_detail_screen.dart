import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/watched_client.dart';
import '../../core/providers.dart';
import '../watcher_providers.dart';

/// クライアント詳細画面。
/// 現在ステータス、ステータス変更履歴（遷移粒度のみ）、通知設定。
/// 行動詳細・最終操作時刻は一切表示しない。
class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.client});
  final WatchedClient client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(statusHistoryProvider(client.id));
    final prefs = ref.watch(prefsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(client.displayName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 現在ステータス
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: client.status.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(client.status.icon,
                      color: client.status.color, size: 48),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client.status.label,
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: client.status.color)),
                      if (client.statusChangedAt != null)
                        Text(
                          _formatDate(client.statusChangedAt!),
                          style: const TextStyle(fontSize: 14),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 通知設定
            Card(
              child: SwitchListTile(
                title: const Text('注視のときに通知',
                    style: TextStyle(fontSize: 18)),
                subtitle: const Text('警告・SOSは常に通知されます',
                    style: TextStyle(fontSize: 14)),
                value: prefs.watchNotifyEnabled,
                onChanged: (v) async {
                  await prefs.setWatchNotifyEnabled(v);
                  ref.invalidate(prefsProvider);
                  (context as Element).markNeedsBuild();
                },
              ),
            ),
            const SizedBox(height: 24),

            const Text('見守りの記録',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            historyAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('履歴を読み込めませんでした: $e'),
              data: (transitions) {
                if (transitions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('まだ記録はありません',
                        style: TextStyle(fontSize: 16)),
                  );
                }
                return Column(
                  children: transitions.reversed
                      .map((t) => Card(
                            child: ListTile(
                              leading: Icon(t.to.icon, color: t.to.color),
                              title: Text('${t.from.label} → ${t.to.label}',
                                  style: const TextStyle(fontSize: 18)),
                              subtitle: Text(_formatDate(t.at),
                                  style: const TextStyle(fontSize: 14)),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final l = d.toLocal();
    return '${l.month}月${l.day}日 ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
