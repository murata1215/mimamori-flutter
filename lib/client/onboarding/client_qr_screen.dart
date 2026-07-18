import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart' show PackageInfo;
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/notifications/fcm_service.dart';
import '../../core/providers.dart';
import 'client_login_screen.dart';
import 'permission_wizard_screen.dart';

/// 逆方向ペアリングのクライアント（見守られる側）画面。
///
/// 高齢者の操作は「同意タップ」まで。この画面では:
/// 1. 起動時に自動プロビジョニング（POST /v1/provisions）
/// 2. QR（claim_code）と手入力用6桁（fallback_code）を大きく表示
/// 3. 数秒間隔でポーリング（GET /v1/provisions/me）
/// 4. コード期限が切れたら自動で再プロビジョニング（高齢者は待つだけ）
/// 5. ウォッチャーが登録（claim）したら自動でホーム設定へ進む
class ClientQrScreen extends ConsumerStatefulWidget {
  const ClientQrScreen({super.key});

  @override
  ConsumerState<ClientQrScreen> createState() => _ClientQrScreenState();
}

class _ClientQrScreenState extends ConsumerState<ClientQrScreen> {
  ProvisionResult? _provision;
  String? _error;
  Timer? _pollTimer;
  DateTime? _expiresAt;
  bool _navigated = false;

  static const _pollInterval = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _provisionAndPoll();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _provisionAndPoll() async {
    _pollTimer?.cancel();
    setState(() {
      _provision = null;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);

      String? appVersion;
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {}
      final fcmToken = await FcmService.token();

      final prov = await api.createProvision(
        platform: Platform.operatingSystem, // 'android' / 'ios'
        consentVersion: AppConfig.consentVersion,
        appVersion: appVersion,
        fcmToken: fcmToken,
      );
      if (!mounted) return;
      setState(() {
        _provision = prov;
        _expiresAt =
            DateTime.now().add(Duration(minutes: prov.expiresInMinutes));
      });
      _pollTimer =
          Timer.periodic(_pollInterval, (_) => _poll(prov.claimSecret));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _poll(String claimSecret) async {
    if (_navigated) return;
    // 期限切れなら再プロビジョニング（高齢者は画面を見ているだけ）。
    final expires = _expiresAt;
    if (expires != null && DateTime.now().isAfter(expires)) {
      await _provisionAndPoll();
      return;
    }
    try {
      final api = ref.read(apiClientProvider);
      final status = await api.getClaimStatus(claimSecret: claimSecret);
      if (status.claimed && status.deviceToken != null) {
        await _onClaimed(status);
      }
    } catch (_) {
      // 一時的な通信エラーはポーリング継続で吸収する。
    }
  }

  Future<void> _onClaimed(ClaimStatus status) async {
    if (_navigated) return;
    _navigated = true;
    _pollTimer?.cancel();

    final prefs = ref.read(prefsProvider);
    if (status.clientId != null) {
      await prefs.setClientId(status.clientId!);
    }
    await prefs.setClientToken(status.deviceToken);
    // device_token 取得後に FCM トークンをサーバーへ同期。
    await FcmService.syncToken();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PermissionWizardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('見守りをはじめる'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _error != null
                ? _errorView()
                : _provision == null
                    ? const CircularProgressIndicator()
                    : _qrView(_provision!),
          ),
        ),
      ),
    );
  }

  Widget _qrView(ProvisionResult prov) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '見守る人に\nこの画面を見せてください',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '家族がこのQRコードを読み取ると\nつながります',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: QrImageView(
              data: prov.claimCode,
              size: 240,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'QRコードが読み取れないときは\nこの番号を伝えてください',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            prov.fallbackCode,
            style: const TextStyle(
                fontSize: 44, fontWeight: FontWeight.bold, letterSpacing: 8),
          ),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('つながるのを待っています…',
                  style: TextStyle(fontSize: 16, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ClientLoginScreen()),
            ),
            child: const Text('機種変更の方はこちら（メールでログイン）',
                style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
        const SizedBox(height: 16),
        const Text('準備に失敗しました',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _provisionAndPoll,
          child: const Text('もう一度'),
        ),
      ],
    );
  }
}
