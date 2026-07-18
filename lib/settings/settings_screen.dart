import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/heartbeat/heartbeat_task.dart';
import '../core/providers.dart';
import '../core/storage/prefs.dart';
import '../client/auth/client_email_screen.dart';
import '../client/onboarding/consent_screen.dart';
import '../watcher/auth/watcher_email_screen.dart';
import '../watcher/auth/watcher_name_screen.dart';

/// 設定画面（共通）。通知・アカウント・退会・ロール追加。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _numberCtrl = TextEditingController();

  @override
  void dispose() {
    _numberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsProvider);
    final roles = prefs.roles;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: SafeArea(
        child: ListView(
          children: [
            const _SectionHeader('通知'),
            SwitchListTile(
              title: const Text('注視のときに通知', style: TextStyle(fontSize: 18)),
              value: prefs.watchNotifyEnabled,
              onChanged: (v) async {
                await prefs.setWatchNotifyEnabled(v);
                setState(() {});
              },
            ),

            if (roles.contains(AppRole.client)) ...[
              const _SectionHeader('SOS の設定'),
              SwitchListTile(
                title: const Text('送信できない時にSMSで送る',
                    style: TextStyle(fontSize: 18)),
                subtitle: const Text('オフライン時に家族へ直接メッセージを送ります',
                    style: TextStyle(fontSize: 13)),
                value: prefs.smsFallbackEnabled,
                onChanged: (v) async {
                  await prefs.setSmsFallbackEnabled(v);
                  setState(() {});
                },
              ),
              if (prefs.smsFallbackEnabled)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...prefs.fallbackNumbers.map((n) => ListTile(
                            leading: const Icon(Icons.phone),
                            title: Text(n, style: const TextStyle(fontSize: 16)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final list = [...prefs.fallbackNumbers]..remove(n);
                                await prefs.setFallbackNumbers(list);
                                setState(() {});
                              },
                            ),
                          )),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _numberCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: '電話番号を追加',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle,
                                size: 32, color: Color(0xFF00695C)),
                            onPressed: () async {
                              final n = _numberCtrl.text.trim();
                              if (n.isEmpty) return;
                              final list = [...prefs.fallbackNumbers, n];
                              await prefs.setFallbackNumbers(list);
                              _numberCtrl.clear();
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],

            const _SectionHeader('役割の追加'),
            if (!roles.contains(AppRole.client))
              ListTile(
                leading: const Icon(Icons.self_improvement),
                title: const Text('自分も見守られる', style: TextStyle(fontSize: 18)),
                onTap: () async {
                  await prefs.addRole(AppRole.client);
                  if (!context.mounted) return;
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ConsentScreen(),
                  ));
                },
              ),
            if (!roles.contains(AppRole.watcher))
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('家族を見守る', style: TextStyle(fontSize: 18)),
                onTap: () async {
                  await prefs.addRole(AppRole.watcher);
                  if (!context.mounted) return;
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const WatcherNameScreen(),
                  ));
                },
              ),
            if (roles.length > 1)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(
                  prefs.activeRole == AppRole.client
                      ? '見守る画面に切り替える'
                      : '見守られる画面に切り替える',
                  style: const TextStyle(fontSize: 18),
                ),
                onTap: () async {
                  final next = prefs.activeRole == AppRole.client
                      ? AppRole.watcher
                      : AppRole.client;
                  await prefs.setActiveRole(next);
                  if (!context.mounted) return;
                  _restartToRoot(context, prefs);
                },
              ),

            const _SectionHeader('アカウント'),
            if (roles.contains(AppRole.watcher)) ...[
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('お名前を変更', style: TextStyle(fontSize: 18)),
                subtitle: Text(
                  prefs.watcherDisplayName ?? '未設定',
                  style: const TextStyle(fontSize: 14),
                ),
                onTap: () => _editWatcherName(context, prefs),
              ),
              if (prefs.watcherEmailRegistered)
                const ListTile(
                  leading: Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                  title: Text('メール登録済み', style: TextStyle(fontSize: 18)),
                  subtitle: Text('機種変更のときに引き継げます',
                      style: TextStyle(fontSize: 14)),
                )
              else
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('メールアドレスを登録',
                      style: TextStyle(fontSize: 18)),
                  subtitle: const Text('機種変更にそなえて引き継げるようにします',
                      style: TextStyle(fontSize: 14)),
                  onTap: () async {
                    final registered = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const WatcherEmailScreen(),
                      ),
                    );
                    if (registered == true) setState(() {});
                  },
                ),
            ],
            if (roles.contains(AppRole.client)) ...[
              if (prefs.clientEmailRegistered)
                const ListTile(
                  leading: Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                  title: Text('メール登録済み', style: TextStyle(fontSize: 18)),
                  subtitle: Text('機種変更のときに引き継げます',
                      style: TextStyle(fontSize: 14)),
                )
              else
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('メールアドレスを登録',
                      style: TextStyle(fontSize: 18)),
                  subtitle: const Text('機種変更にそなえて引き継げるようにします',
                      style: TextStyle(fontSize: 14)),
                  onTap: () async {
                    final registered = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const ClientEmailScreen(),
                      ),
                    );
                    if (registered == true) setState(() {});
                  },
                ),
            ],
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('退会する',
                  style: TextStyle(fontSize: 18, color: Colors.redAccent)),
              onTap: () => _confirmDelete(context, prefs),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text('みまもり Phase 1 (MVP)',
                  style: TextStyle(fontSize: 13, color: Colors.black45)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _editWatcherName(BuildContext context, Prefs prefs) async {
    final ctrl = TextEditingController(text: prefs.watcherDisplayName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('お名前を変更'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(
            hintText: '例：たろう',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('やめる'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('変更する'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;

    final token = prefs.watcherToken;
    if (token != null) {
      try {
        await ref
            .read(apiClientProvider)
            .updateWatcherDisplayName(watcherToken: token, displayName: name);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('変更に失敗しました。もう一度お試しください。')),
          );
        }
        return;
      }
    }
    await prefs.setWatcherDisplayName(name);
    if (mounted) setState(() {});
  }

  Future<void> _confirmDelete(BuildContext context, Prefs prefs) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('退会しますか？'),
        content: const Text('すべての設定が削除されます。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('やめる'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退会する',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await HeartbeatScheduler.stop();
      await prefs.clearAll();
      if (!context.mounted) return;
      _restartToRoot(context, prefs);
    }
  }

  /// ロール切替 / 退会後にアプリのルート画面へ遷移し直す。
  void _restartToRoot(BuildContext context, Prefs prefs) {
    rootNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => rootScreenFor(prefs)),
      (r) => false,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF00695C),
        ),
      ),
    );
  }
}
