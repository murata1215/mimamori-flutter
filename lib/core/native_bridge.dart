import 'package:flutter/services.dart';

/// Kotlin 側 (MainActivity) との MethodChannel 橋渡し。
/// 生存イベント収集・権限確認・OEM ガイドを担う。
class NativeBridge {
  static const _channel = MethodChannel('mimamori/native');

  /// 直近ウィンドウの SCREEN_ON 回数を取得（取得後 0 にリセット）。
  static Future<int> getScreenOnCount() async {
    try {
      return await _channel.invokeMethod<int>('getScreenOnCount') ?? 0;
    } on MissingPluginException {
      return 0; // 非 Android / テスト環境
    } on PlatformException {
      return 0;
    }
  }

  /// 直近 windowMinutes 分に前面アプリ利用があったか（boolean のみ）。
  static Future<bool> hasRecentAppUsage({int windowMinutes = 15}) async {
    try {
      return await _channel.invokeMethod<bool>(
            'hasRecentAppUsage',
            {'windowMinutes': windowMinutes},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isUsageAccessGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isUsageAccessGranted') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openUsageAccessSettings() async {
    try {
      await _channel.invokeMethod('openUsageAccessSettings');
    } catch (_) {}
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  /// OEM の自動起動 / 電池管理設定を開く（開けたら true）。
  static Future<bool> openOemAutostartSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openOemAutostartSettings') ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<String> getManufacturer() async {
    try {
      return await _channel.invokeMethod<String>('getManufacturer') ?? '';
    } catch (_) {
      return '';
    }
  }

  /// SCREEN_ON レシーバの動的登録（アプリ起動時に呼ぶ）。
  static Future<void> registerScreenReceiver() async {
    try {
      await _channel.invokeMethod('registerScreenReceiver');
    } catch (_) {}
  }
}
