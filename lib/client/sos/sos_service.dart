import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/prefs.dart';
import '../location/location_cache.dart';

/// SOS 発動のコアロジック。
///
/// 位置情報はこのサービス内でのみ取得する（プライバシー原則: 他モジュールから
/// geolocator を import しない）。SOS 時のみ・単発取得。
class SosService {
  SosService(this._api, this._prefs);
  final ApiClient _api;
  final Prefs _prefs;

  /// SOS を送信。
  /// 1) その時点の GPS を単発取得（新規測位、失敗時は端末内キャッシュ位置へフォールバック）
  /// 2) 電池残量を付与
  /// 3) サーバーへ送信。失敗時は SMS フォールバック（事前許可制）
  Future<SosSendResult> fire() async {
    final token = _prefs.clientToken;

    double? lat;
    double? lng;
    DateTime? capturedAt; // キャッシュ由来のときだけ「◯分前の位置」として送る
    final fix = await _resolveLocation();
    if (fix != null) {
      lat = fix.lat;
      lng = fix.lng;
      capturedAt = fix.capturedAt; // 新規測位なら null
    }

    int battery = 0;
    try {
      battery = await Battery().batteryLevel;
    } catch (_) {}

    if (token != null) {
      try {
        final incidentId = await _api.sendSos(
          clientToken: token,
          lat: lat,
          lng: lng,
          batteryLevel: battery,
          capturedAt: capturedAt,
        );
        return SosSendResult(success: true, incidentId: incidentId);
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

  /// SOS 用の位置を解決する。
  /// 1) 位置サービス OFF → 新規測位はスキップしてキャッシュへ
  /// 2) 権限 denied → その場で1回だけ再要求（ワンタップで許可可能に）
  /// 3) 新規測位（高精度・10秒上限）を試み、失敗したら 24h 以内のキャッシュ位置
  /// 戻り値の capturedAt は「キャッシュ由来のときのみ」非 null。新規測位は null。
  Future<_ResolvedFix?> _resolveLocation() async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (serviceOn) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission(); // 緊急時にワンタップ許可
        }
        if (perm == LocationPermission.always ||
            perm == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          // 新規測位はキャッシュも更新しておく。
          await _prefs.setLastFix(pos.latitude, pos.longitude, DateTime.now());
          return _ResolvedFix(lat: pos.latitude, lng: pos.longitude);
        }
      }
    } catch (e) {
      debugPrint('[SOS] fresh location unavailable: $e');
    }

    // フォールバック: 端末内キャッシュ（24h 以内）。
    final cached = LocationCache.recentCachedFix(_prefs);
    if (cached != null) {
      debugPrint('[SOS] using cached location (${cached.capturedAt})');
      return _ResolvedFix(
        lat: cached.lat,
        lng: cached.lng,
        capturedAt: cached.capturedAt,
      );
    }
    return null; // 位置不明のまま送信を優先
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
  final String? incidentId;

  const SosSendResult({
    required this.success,
    this.smsSent = false,
    this.incidentId,
  });
}

/// SOS 用に解決した位置1点。capturedAt はキャッシュ由来のときのみ非 null。
class _ResolvedFix {
  final double lat;
  final double lng;
  final DateTime? capturedAt;
  const _ResolvedFix({required this.lat, required this.lng, this.capturedAt});
}
