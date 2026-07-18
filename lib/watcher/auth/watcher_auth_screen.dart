import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/fcm_service.dart';
import '../../core/providers.dart';
import '../watcher_shell.dart';

/// ウォッチャーのログイン / 登録（メール+パスワード。Phase 1）。
class WatcherAuthScreen extends ConsumerStatefulWidget {
  const WatcherAuthScreen({super.key});

  @override
  ConsumerState<WatcherAuthScreen> createState() => _WatcherAuthScreenState();
}

class _WatcherAuthScreenState extends ConsumerState<WatcherAuthScreen> {
  bool _isRegister = false;
  bool _busy = false;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      final auth = _isRegister
          ? await api.registerWatcher(
              email: _email.text.trim(),
              password: _password.text,
              displayName: _name.text.trim(),
            )
          : await api.loginWatcher(
              email: _email.text.trim(),
              password: _password.text,
            );
      final prefs = ref.read(prefsProvider);
      await prefs.setWatcherToken(auth.accessToken);
      await prefs.setWatcherRefreshToken(auth.refreshToken);
      await prefs.setWatcherId(auth.watcherId);
      // メールで登録/ログインした = メール登録済みアカウント（設定画面の表示用）。
      await prefs.setWatcherEmailRegistered(true);
      if (_name.text.trim().isNotEmpty) {
        await prefs.setWatcherDisplayName(_name.text.trim());
      }
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
      appBar: AppBar(title: Text(_isRegister ? '新規登録' : 'ログイン')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              if (_isRegister) ...[
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'お名前',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'メールアドレス',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'パスワード',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isRegister ? '登録する' : 'ログイン'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _isRegister = !_isRegister),
                child: Text(_isRegister
                    ? 'アカウントをお持ちの方はこちら'
                    : '新規登録はこちら'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
