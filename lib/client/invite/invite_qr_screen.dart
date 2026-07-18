import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';

/// 「見守る人を追加」画面（複数見守り: 2人目・3人目の家族を紐づける）。
///
/// 初回ペアリング（ClientQrScreen）とは別で、claim 済み端末が
/// 追加ウォッチャー用の招待コードを発行して見せるだけ。高齢者の操作はボタン1つ。
/// 1. 開いたら自動で招待コード発行（POST /v1/invite-codes）
/// 2. QR（invite_code）と手入力用6桁（fallback_code）を大きく表示
/// 3. 数秒間隔でポーリング（GET /v1/invite-codes/:id）
/// 4. コード期限が切れたら自動で再発行
/// 5. 誰かが参加したら「〇〇さんが登録しました」を表示して閉じる
class InviteQrScreen extends ConsumerStatefulWidget {
  const InviteQrScreen({super.key});

  @override
  ConsumerState<InviteQrScreen> createState() => _InviteQrScreenState();
}

class _InviteQrScreenState extends ConsumerState<InviteQrScreen> {
  InviteResult? _invite;
  String? _error;
  String? _joinedName;
  Timer? _pollTimer;
  DateTime? _expiresAt;
  bool _done = false;

  static const _pollInterval = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _issueAndPoll();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  String get _clientToken =>
      ref.read(prefsProvider).clientToken ?? 'mock-client-token';

  Future<void> _issueAndPoll() async {
    _pollTimer?.cancel();
    setState(() {
      _invite = null;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final inv = await api.createInviteCode(clientToken: _clientToken);
      if (!mounted) return;
      setState(() {
        _invite = inv;
        _expiresAt = DateTime.now().add(Duration(minutes: inv.expiresInMinutes));
      });
      _pollTimer = Timer.periodic(_pollInterval, (_) => _poll(inv.inviteId));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _poll(String inviteId) async {
    if (_done) return;
    final expires = _expiresAt;
    if (expires != null && DateTime.now().isAfter(expires)) {
      await _issueAndPoll();
      return;
    }
    try {
      final api = ref.read(apiClientProvider);
      final status =
          await api.getInviteStatus(clientToken: _clientToken, inviteId: inviteId);
      if (status.joined) {
        _onJoined(status.watcherName);
      }
    } catch (_) {
      // 一時的な通信エラーはポーリング継続で吸収する。
    }
  }

  void _onJoined(String? watcherName) {
    if (_done) return;
    _done = true;
    _pollTimer?.cancel();
    if (!mounted) return;
    setState(() => _joinedName = watcherName ?? 'あたらしい見守り人');
    // 成功表示を見せてから閉じる（呼び出し元でリスト更新）。
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('見守る人を追加')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _joinedName != null
                ? _joinedView(_joinedName!)
                : _error != null
                    ? _errorView()
                    : _invite == null
                        ? const CircularProgressIndicator()
                        : _qrView(_invite!),
          ),
        ),
      ),
    );
  }

  Widget _qrView(InviteResult inv) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'あたらしく見守る人に\nこの画面を見せてください',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '家族がこのQRコードを読み取ると\n見守りに加わります',
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
              data: inv.inviteCode,
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
            inv.fallbackCode,
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
              Text('登録されるのを待っています…',
                  style: TextStyle(fontSize: 16, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _joinedView(String name) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, size: 96, color: Color(0xFF2E7D32)),
        const SizedBox(height: 24),
        Text(
          '$name さんが\n見守りに加わりました',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
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
          onPressed: _issueAndPoll,
          child: const Text('もう一度'),
        ),
      ],
    );
  }
}
