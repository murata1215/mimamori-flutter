import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import 'billing_service.dart';

/// ペイウォール。3人目以降の追加時に表示。
/// プラン: 月額100円/人（従量）。法人・請求書払いは問い合わせ導線。
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _busy = false;

  Future<void> _purchase() async {
    setState(() => _busy = true);
    final billing = BillingService.create();
    final ok = await billing.purchasePerClient();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('購入を完了できませんでした')),
      );
    }
  }

  Future<void> _contactCorporate() async {
    final uri = Uri.parse('mailto:sales@example.com?subject=法人利用の相談');
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('見守りを追加')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Icon(Icons.people, size: 72, color: Color(0xFF00695C)),
              const SizedBox(height: 16),
              const Text('3人目以降の見守り',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('2人までは無料でご利用いただけます。\n3人目からは1人ごとに月額料金がかかります。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 32),
              Card(
                color: const Color(0xFFE0F2F1),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text('月額 ${AppConfig.perClientYen}円 / 人',
                          style: const TextStyle(
                              fontSize: 30, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('追加する人数分', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _busy ? null : _purchase,
                child: _busy
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('購入して追加する'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _contactCorporate,
                child: const Text('法人でのご利用はこちら'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
