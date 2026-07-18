import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart' show PackageInfo;

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/notifications/fcm_service.dart';
import '../../core/providers.dart';
import 'permission_wizard_screen.dart';

/// 機種変更（新端末）時のクライアント（見守られ側）ログイン画面。
///
/// メール登録しておけば、新端末でメールログイン → 同じ client_id を継続。
/// 見守り関係（watch_links）・スタンプ履歴・ステータス履歴はそのまま、
/// ウォッチャー側の再登録は不要。旧端末はサーバー側で自動的に無効化される。
///
/// 高齢者本人には難しいので、家族が代行入力する想定（フォントは大きめ）。
class ClientLoginScreen extends ConsumerStatefulWidget {
  const ClientLoginScreen({super.key});

  @override
  ConsumerState<ClientLoginScreen> createState() => _ClientLoginScreenState();
}

class _ClientLoginScreenState extends ConsumerState<ClientLoginScreen> {
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
      final api = ref.read(apiClientProvider);

      String? appVersion;
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {}
      final fcmToken = await FcmService.token();

      final result = await api.loginClient(
        email: email,
        password: password,
        platform: Platform.operatingSystem,
        consentVersion: AppConfig.consentVersion,
        appVersion: appVersion,
        fcmToken: fcmToken,
      );

      final prefs = ref.read(prefsProvider);
      await prefs.setClientId(result.clientId);
      await prefs.setDeviceId(result.deviceId);
      await prefs.setClientToken(result.deviceToken);
      await prefs.setClientEmailRegistered(true);
      // 新端末で同意を記録し直す（法務要件・新インストール扱い）。
      await prefs.setConsent(AppConfig.consentVersion, DateTime.now());
      // device_token 取得後に FCM トークンをサーバーへ同期。
      await FcmService.syncToken();

      if (!mounted) return;
      // 新端末は権限設定をやり直す（既存のオンボーディング完了フロー）。
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PermissionWizardScreen()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.statusCode == 401
          ? 'メールアドレスまたはパスワードが違います'
          : 'ログインに失敗しました。もう一度お試しください。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      setState(() => _busy = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインに失敗しました。もう一度お試しください。')),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('メールでログイン')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                '前の端末で登録したメールアドレスで\nログインすると、見守りを引き継げます',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'メールアドレス',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'パスワード',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('ログイン', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
