import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/storage/prefs.dart';

/// 位置の取得・端末内キャッシュ・移動判定を一手に担うモジュール。
///
/// プライバシー原則:
///  - 座標をサーバーへ送るのは SOS 時のみ（sos_service.dart）。
///  - ハートビートには boolean の had_movement しか載せない。
///  - キャッシュは最新1点のみ（履歴・軌跡は持たない）。
///
/// 電池コスト最小化:
///  - まず getLastKnownPosition()（測位せず OS キャッシュを読むだけ、コストほぼゼロ）。
///  - なければ低精度・5秒上限で単発測位。
class LocationCache {
  /// 前回キャッシュと比べて「移動あり」と判定するしきい値（メートル）。
  static const double movementThresholdMeters = 100;

  /// SOS フォールバックで許容するキャッシュの鮮度（これより古いと使わない）。
  static const Duration maxCacheAge = Duration(hours: 24);

  /// 現在位置を取得して端末内にキャッシュし、移動有無を返す。
  ///
  /// 戻り値:
  ///  - true/false : 位置を取得でき、前回比で移動あり/なし
  ///  - null       : 権限なし・位置サービス OFF・測位失敗（サーバーへは送らない）
  static Future<bool?> captureAndCache(Prefs prefs) async {
    final pos = await _obtainPosition();
    if (pos == null) return null;

    final prevLat = prefs.lastFixLat;
    final prevLng = prefs.lastFixLng;

    bool? moved;
    if (prevLat != null && prevLng != null) {
      final meters = Geolocator.distanceBetween(
        prevLat,
        prevLng,
        pos.latitude,
        pos.longitude,
      );
      moved = meters >= movementThresholdMeters;
    }

    await prefs.setLastFix(pos.latitude, pos.longitude, DateTime.now());
    // 初回（前回位置なし）は移動判定できないので false 扱い（測位できた＝端末は動いている可能性はあるが、
    // 移動シグナルとしては保守的に false）。
    return moved ?? false;
  }

  /// SOS 用: maxCacheAge 以内のキャッシュ位置を返す。古い/無ければ null。
  static CachedFix? recentCachedFix(Prefs prefs) {
    final lat = prefs.lastFixLat;
    final lng = prefs.lastFixLng;
    final at = prefs.lastFixAt;
    if (lat == null || lng == null || at == null) return null;
    if (DateTime.now().difference(at) > maxCacheAge) return null;
    return CachedFix(lat: lat, lng: lng, capturedAt: at);
  }

  /// 位置を1点取得する（測位コストを抑える）。取得できなければ null。
  static Future<Position?> _obtainPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }

      // まず OS キャッシュ（測位しない＝電池コストほぼゼロ）。
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;

      // なければ低精度で単発測位（上限5秒）。
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint('[LocationCache] obtain failed: $e');
      return null;
    }
  }
}

/// 端末内にキャッシュされた位置1点。
class CachedFix {
  final double lat;
  final double lng;
  final DateTime capturedAt;

  const CachedFix({
    required this.lat,
    required this.lng,
    required this.capturedAt,
  });
}
