import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/sos_incident.dart';
import '../../core/providers.dart';

/// SOS 受信画面（地図含む）。
/// 位置・電池残量・発動時刻を表示。SOS 解決後は位置へのアクセス不可
/// （サーバー側で位置データが期限削除される）。
///
/// 軽量化のため地図タイルは埋め込まず、外部地図アプリ起動リンクで表示する
/// （限界費用ゼロ近傍の原則に沿い、逆ジオコーディング等は行わない）。
class SosMapScreen extends ConsumerStatefulWidget {
  const SosMapScreen({super.key, required this.incidentId});
  final String incidentId;

  @override
  ConsumerState<SosMapScreen> createState() => _SosMapScreenState();
}

class _SosMapScreenState extends ConsumerState<SosMapScreen> {
  SosIncident? _incident;
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = ref.read(prefsProvider);
    final token = prefs.watcherToken ?? 'mock-watcher-token';
    try {
      final inc = await ref
          .read(apiClientProvider)
          .getSos(watcherToken: token, incidentId: widget.incidentId);
      if (!mounted) return;
      setState(() {
        _incident = inc;
        _notFound = inc == null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notFound = true;
      });
    }
  }

  Future<void> _openMap(SosIncident inc) async {
    if (!inc.hasLocation) return;
    final uri = Uri.parse(
        'https://maps.google.com/?q=${inc.latitude},${inc.longitude}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _resolve(SosIncident inc) async {
    final prefs = ref.read(prefsProvider);
    final token = prefs.watcherToken ?? 'mock-watcher-token';
    await ref
        .read(apiClientProvider)
        .resolveSos(watcherToken: token, incidentId: inc.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7B1FA2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        title: const Text('🆘 SOS',
            style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : _notFound || _incident == null
                ? _resolvedView()
                : _detailView(_incident!),
      ),
    );
  }

  Widget _resolvedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle, size: 96, color: Colors.white),
            SizedBox(height: 16),
            Text('このSOSは解決済みです',
                style: TextStyle(color: Colors.white, fontSize: 22)),
            SizedBox(height: 8),
            Text('位置情報は削除されています',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _detailView(SosIncident inc) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inc.clientName ?? '見守り対象',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _row(Icons.access_time, '発動時刻',
                      _formatDate(inc.firedAt)),
                  _row(Icons.battery_std, '電池残量', '${inc.batteryLevel}%'),
                  _row(
                    Icons.location_on,
                    '位置',
                    inc.hasLocation
                        ? '${inc.latitude!.toStringAsFixed(5)}, ${inc.longitude!.toStringAsFixed(5)}'
                        : '位置不明',
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (inc.hasLocation)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF7B1FA2),
              ),
              icon: const Icon(Icons.map),
              label: const Text('地図で場所を見る'),
              onPressed: () => _openMap(inc),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
            ),
            icon: const Icon(Icons.done_all),
            label: const Text('解決した'),
            onPressed: () => _resolve(inc),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.black54),
          const SizedBox(width: 12),
          Text('$label: ',
              style: const TextStyle(fontSize: 16, color: Colors.black54)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final l = d.toLocal();
    return '${l.month}月${l.day}日 ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
