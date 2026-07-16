import 'package:flutter_test/flutter_test.dart';

import 'package:mimamori_flutter/core/models/client_status.dart';
import 'package:mimamori_flutter/core/models/heartbeat.dart';
import 'package:mimamori_flutter/core/models/sos_incident.dart';

final _fixedTime = DateTime.utc(2026, 7, 16, 12, 0);

void main() {
  group('ClientStatus', () {
    test('API 値との相互変換が対称であること', () {
      for (final s in [
        ClientStatus.alive,
        ClientStatus.watch,
        ClientStatus.confirming,
        ClientStatus.alert,
        ClientStatus.sos,
      ]) {
        expect(ClientStatus.fromApi(s.apiValue), s);
      }
    });

    test('未知の値は unknown（設定に問題）にフォールバックする', () {
      expect(ClientStatus.fromApi('NONSENSE'), ClientStatus.unknown);
      expect(ClientStatus.fromApi(null), ClientStatus.unknown);
    });
  });

  group('Heartbeat', () {
    test('プライバシー: 送信 JSON は許可された4キーのみを含む', () {
      final hb = Heartbeat(
        occurredAt: _fixedTime,
        batteryLevel: 80,
        screenOnCount: 3,
        hadAppUsage: true,
        appVersion: '1.0.0+1',
      );
      final json = hb.toJson();
      expect(
        json.keys.toSet(),
        {
          'occurred_at',
          'battery_level',
          'screen_on_count',
          'had_app_usage',
          'app_version',
        },
      );
      // 行動詳細（アプリ名・URL等）を漏らすキーが無いこと
      expect(json.containsKey('app_name'), isFalse);
      expect(json.containsKey('url'), isFalse);
    });

    test('JSON ラウンドトリップで値が保持されること', () {
      final hb = Heartbeat(
        occurredAt: _fixedTime,
        batteryLevel: 55,
        screenOnCount: 2,
        hadAppUsage: false,
        appVersion: '1.2.3+4',
      );
      final restored = Heartbeat.fromJson(hb.toJson());
      expect(restored.batteryLevel, 55);
      expect(restored.screenOnCount, 2);
      expect(restored.hadAppUsage, false);
      expect(restored.occurredAt, hb.occurredAt);
    });
  });

  group('SosIncident', () {
    test('位置の有無を正しく判定する', () {
      final withLoc = SosIncident(
        id: 'a',
        clientId: 'c',
        latitude: 35.0,
        longitude: 139.0,
        batteryLevel: 50,
        firedAt: _fixedTime,
      );
      expect(withLoc.hasLocation, isTrue);
      expect(withLoc.isResolved, isFalse);

      final noLoc = SosIncident(
        id: 'b',
        clientId: 'c',
        batteryLevel: 50,
        firedAt: _fixedTime,
      );
      expect(noLoc.hasLocation, isFalse);
    });
  });
}
