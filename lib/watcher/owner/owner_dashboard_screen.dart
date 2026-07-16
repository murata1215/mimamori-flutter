import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/client_status.dart';
import '../../core/models/watched_client.dart';
import '../watcher_providers.dart';

/// オーナーダッシュボード（有料プラン機能）。
/// Phase 1 では画面骨格＋物件別サマリのみ。
/// CSV エクスポート・月次レポートはサーバー実装後に結線。
class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(watchedClientsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('オーナーダッシュボード')),
      body: SafeArea(
        child: clientsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (clients) {
            final byProperty = <String, List<WatchedClient>>{};
            for (final c in clients) {
              byProperty.putIfAbsent(c.propertyTag ?? '未分類', () => []).add(c);
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final entry in byProperty.entries)
                  _PropertyCard(name: entry.key, clients: entry.value),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('アラート履歴をCSVで書き出す',
                        style: TextStyle(fontSize: 16)),
                    subtitle: const Text('サーバー連携後に有効になります',
                        style: TextStyle(fontSize: 13)),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('準備中です')),
                      );
                    },
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf),
                    title: const Text('月次見守り稼働レポート',
                        style: TextStyle(fontSize: 16)),
                    subtitle: const Text('サーバー連携後に有効になります',
                        style: TextStyle(fontSize: 13)),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('準備中です')),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.name, required this.clients});
  final String name;
  final List<WatchedClient> clients;

  @override
  Widget build(BuildContext context) {
    final alive =
        clients.where((c) => c.status == ClientStatus.alive).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${clients.length}人中 生存$alive',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: clients
                  .map((c) => Chip(
                        avatar: Icon(c.status.icon,
                            color: c.status.color, size: 18),
                        label: Text(c.displayName),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
