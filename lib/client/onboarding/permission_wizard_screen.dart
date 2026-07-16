import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/heartbeat/heartbeat_task.dart';
import '../../core/native_bridge.dart';
import '../../core/providers.dart';
import '../client_shell.dart';

/// 権限設定ウィザード（順番に1つずつ、各ステップに図解）。
/// 通知 → 使用状況アクセス → 電池最適化除外 → OEM別ガイド → 位置情報。
class PermissionWizardScreen extends ConsumerStatefulWidget {
  const PermissionWizardScreen({super.key});

  @override
  ConsumerState<PermissionWizardScreen> createState() =>
      _PermissionWizardScreenState();
}

class _PermissionWizardScreenState
    extends ConsumerState<PermissionWizardScreen> {
  int _step = 0;
  String _manufacturer = '';
  bool _needsOemGuide = false;

  @override
  void initState() {
    super.initState();
    _detectOem();
  }

  Future<void> _detectOem() async {
    final m = (await NativeBridge.getManufacturer()).toLowerCase();
    const killers = ['xiaomi', 'oppo', 'realme', 'vivo', 'huawei', 'honor', 'meizu', 'oneplus'];
    setState(() {
      _manufacturer = m;
      _needsOemGuide = killers.any((k) => m.contains(k));
    });
  }

  List<_WizardStep> get _steps {
    return [
      _WizardStep(
        icon: Icons.notifications_active,
        title: '通知を許可',
        body: '見守りからの「無事ですか？」の確認や、\nお知らせを受け取るために必要です。',
        action: () async {
          await Permission.notification.request();
        },
      ),
      _WizardStep(
        icon: Icons.timeline,
        title: '使用状況へのアクセス',
        body: 'スマホを使っていること（＝お元気なこと）を\n見守りに伝えるために必要です。\n\n「何を使ったか」は送られません。',
        action: () async {
          await NativeBridge.openUsageAccessSettings();
        },
        actionLabel: '設定画面を開く',
      ),
      _WizardStep(
        icon: Icons.battery_charging_full,
        title: '電池の最適化を外す',
        body: 'この設定を外さないと、見守りが\n止まってしまうことがあります。\n\n「許可」を選んでください。',
        action: () async {
          await NativeBridge.requestIgnoreBatteryOptimizations();
        },
        actionLabel: '設定する',
      ),
      if (_needsOemGuide)
        _WizardStep(
          icon: Icons.phonelink_setup,
          title: 'この機種の追加設定',
          body: 'お使いの機種（${_manufacturer.isEmpty ? "この端末" : _manufacturer}）は、\nアプリを自動的に止めることがあります。\n\n「自動起動」を許可してください。',
          action: () async {
            final ok = await NativeBridge.openOemAutostartSettings();
            if (!ok && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('設定 > アプリ > みまもり から「自動起動」を許可してください',
                    style: TextStyle(fontSize: 16)),
              ));
            }
          },
          actionLabel: '設定画面を開く',
        ),
      _WizardStep(
        icon: Icons.location_on,
        title: '位置情報（SOS時のみ）',
        body: 'SOSボタンを押した時だけ、\n居場所を家族に伝えます。\n\nそれ以外では使いません。',
        action: () async {
          await Geolocator.requestPermission();
        },
      ),
    ];
  }

  Future<void> _next() async {
    final steps = _steps;
    if (_step < steps.length - 1) {
      setState(() => _step++);
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = ref.read(prefsProvider);
    await prefs.setClientOnboarded(true);
    await HeartbeatScheduler.start();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ClientShell()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final step = steps[_step.clamp(0, steps.length - 1)];

    return Scaffold(
      appBar: AppBar(
        title: Text('設定 ${_step + 1} / ${steps.length}'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_step + 1) / steps.length,
                minHeight: 8,
              ),
              const Spacer(),
              Icon(step.icon, size: 96, color: const Color(0xFF00695C)),
              const SizedBox(height: 24),
              Text(step.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text(step.body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, height: 1.5)),
              const Spacer(),
              ElevatedButton(
                onPressed: () async {
                  await step.action();
                },
                child: Text(step.actionLabel),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _next,
                child: Text(_step < steps.length - 1 ? '次へ' : '完了'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WizardStep {
  final IconData icon;
  final String title;
  final String body;
  final Future<void> Function() action;
  final String actionLabel;

  _WizardStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    this.actionLabel = '許可する',
  });
}
