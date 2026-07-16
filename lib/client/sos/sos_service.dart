import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/models/sos_incident.dart';
import '../../core/storage/prefs.dart';

/// SOS 発動のコアロジック。
///
/// 位置情報はこのサービス内でのみ取得する（プライバシー原則: 他モジュールから
/// geolocator を import しない）。SOS 時のみ・単発取得。
class SosService {
  SosService(this._api, this._prefs);
  final ApiClient _api;
  final Prefs _prefs;

  /// SOS を送信。
  /// 1) その時点の GPS を単発取得（タイムアウト10秒、失敗時は位置なしで送信優先）
  /// 2) 電池残量を付与
  /// 3) サーバーへ送信。失敗時は SMS フォールバック（事前許可制）
  Future<SosSendResult> fire() async {
    final token = _prefs.clientToken;

    double? lat;
    double? lng;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (e) {
      debugPrint('[SOS] location unavailable: $e'); // 位置不明のまま送信を優先
    }

    int battery = 0;
    try {
      battery = await Battery().batteryLevel;
    } catch (_) {}

    if (token != null) {
      try {
        final incident = await _api.sendSos(
          clientToken: token,
          lat: lat,
          lng: lng,
          batteryLevel: battery,
        );
        return SosSendResult(success: true, incident: incident);
      } catch (e) {
        debugPrint('[SOS] server send failed: $e');
      }
    }

    // フォールバック: 端末から直接 SMS 送信（事前許可制）
    if (_prefs.smsFallbackEnabled && _prefs.fallbackNumbers.isNotEmpty) {
      await _sendFallbackSms(lat, lng);
      return SosSendResult(success: false, smsSent: true);
    }

    return const SosSendResult(success: false, smsSent: false);
  }

  Future<void> _sendFallbackSms(double? lat, double? lng) async {
    final mapLink = (lat != null && lng != null)
        ? 'https://maps.google.com/?q=$lat,$lng'
        : '(位置不明)';
    final body = Uri.encodeComponent('【SOS】助けてください。位置: $mapLink');
    final recipients = _prefs.fallbackNumbers.join(',');
    final uri = Uri.parse('smsto:$recipients?body=$body');
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('[SOS] SMS fallback failed: $e');
    }
  }

  /// ウォッチャーへ発信（発動後画面から）。
  Future<void> callWatcher() async {
    final numbers = _prefs.fallbackNumbers;
    if (numbers.isEmpty) return;
    final uri = Uri.parse('tel:${numbers.first}');
    try {
      await launchUrl(uri);
    } catch (_) {}
  }
}

class SosSendResult {
  final bool success;
  final bool smsSent;
  final SosIncident? incident;

  const SosSendResult({
    required this.success,
    this.smsSent = false,
    this.incident,
  });
}
