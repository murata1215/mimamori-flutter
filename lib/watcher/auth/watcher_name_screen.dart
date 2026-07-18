import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/fcm_service.dart';
import '../../core/providers.dart';
import '../watcher_shell.dart';
import 'watcher_auth_screen.dart';

/// ウォッチャー（見守る側）の入口。
///
/// メール登録は不要。名前を1つ入れて「はじめる」だけで匿名アカウントを作り、
/// すぐ QR スキャンへ進める。メール登録は後から設定画面で任意に行える。
class WatcherNameScreen extends ConsumerStatefulWidget {
  const WatcherNameScreen({super.key});

  @override
  ConsumerState<WatcherNameScreen> createState() => _WatcherNameScreenState();
}

class _WatcherNameScreenState extends ConsumerState<WatcherNameScreen> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('お名前を入力してください')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      final prefs = ref.read(prefsProvider);
      final auth = await api.registerWatcherDevice(
        installId: prefs.watcherInstallId,
        displayName: name,
        platform: Platform.operatingSystem, // 'android' / 'ios'
      );
      await prefs.setWatcherToken(auth.accessToken);
      await prefs.setWatcherRefreshToken(auth.refreshToken);
      await prefs.setWatcherId(auth.watcherId);
      await prefs.setWatcherDisplayName(name);
      // ウォッチャーの FCM トークンをサーバーへ登録（失敗しても続行）
      await FcmService.syncToken();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WatcherShell()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('うまくいきませんでした。もう一度お試しください。')),
        );
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('見守りをはじめる')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.visibility, size: 64, color: Color(0xFF1565C0)),
              const SizedBox(height: 24),
              const Text(
                'あなたのお名前を教えてください',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '見守る相手に「誰が見守っているか」が\n表示されます',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _name,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _start(),
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  labelText: 'お名前',
                  hintText: '例：たろう',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _busy ? null : _start,
                  child: _busy
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('はじめる', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WatcherAuthScreen(),
                          ),
                        ),
                child: const Text('機種変更の方（メール登録済み）はこちら'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
