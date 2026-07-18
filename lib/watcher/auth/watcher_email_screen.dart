import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';

/// 匿名ウォッチャーに後からメール+パスワードを付与する画面（任意）。
///
/// 目的: 機種変更・アンインストール時の復元、別端末でのログイン。
/// 成功したら `Navigator.pop(true)` で呼び出し元に登録完了を通知する。
class WatcherEmailScreen extends ConsumerStatefulWidget {
  const WatcherEmailScreen({super.key});

  @override
  ConsumerState<WatcherEmailScreen> createState() => _WatcherEmailScreenState();
}

class _WatcherEmailScreenState extends ConsumerState<WatcherEmailScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メールアドレスとパスワードを入力してください')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final prefs = ref.read(prefsProvider);
      final token = prefs.watcherToken;
      if (token == null) throw const ApiException('no token');
      await ref.read(apiClientProvider).registerWatcherEmail(
            watcherToken: token,
            email: email,
            password: password,
          );
      await prefs.setWatcherEmailRegistered(true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メールアドレスを登録しました')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.statusCode == 409
          ? 'このメールアドレスは使えません（すでに登録されています）'
          : '登録に失敗しました。もう一度お試しください。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      setState(() => _busy = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登録に失敗しました。もう一度お試しください。')),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('メールアドレスを登録')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                '機種変更や再インストールのときに\n見守り設定を引き継げるようになります',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 24),
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
                    : const Text('登録する'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
