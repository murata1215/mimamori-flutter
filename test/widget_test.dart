import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:mimamori_flutter/client/location/location_cache.dart';
import 'package:mimamori_flutter/core/api/api_client.dart';
import 'package:mimamori_flutter/core/api/mock_api_client.dart';
import 'package:mimamori_flutter/core/models/client_status.dart';
import 'package:mimamori_flutter/core/models/daily_activity.dart';
import 'package:mimamori_flutter/core/models/heartbeat.dart';
import 'package:mimamori_flutter/core/models/sos_incident.dart';
import 'package:mimamori_flutter/core/models/stamp.dart';
import 'package:mimamori_flutter/core/models/watched_client.dart';
import 'package:mimamori_flutter/core/storage/prefs.dart';

final _fixedTime = DateTime.utc(2026, 7, 16, 12, 0);

final _uuidV4Re = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

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

    test('had_movement は未設定なら JSON に含まれない（座標も出さない）', () {
      final hb = Heartbeat(
        occurredAt: _fixedTime,
        batteryLevel: 80,
        screenOnCount: 1,
        hadAppUsage: true,
        appVersion: '1.0.0+1',
      );
      final json = hb.toJson();
      expect(json.containsKey('had_movement'), isFalse);
      // 位置に関するキーは一切出さない
      expect(json.containsKey('lat'), isFalse);
      expect(json.containsKey('lng'), isFalse);
    });

    test('had_movement を設定すると boolean のみ載る（座標は載らない）', () {
      final hb = Heartbeat(
        occurredAt: _fixedTime,
        batteryLevel: 80,
        screenOnCount: 1,
        hadAppUsage: false,
        hadMovement: true,
        appVersion: '1.0.0+1',
      );
      final json = hb.toJson();
      expect(json['had_movement'], true);
      expect(json.containsKey('lat'), isFalse);
      expect(json.containsKey('lng'), isFalse);

      final restored = Heartbeat.fromJson(json);
      expect(restored.hadMovement, true);
    });
  });

  group('WatchedClient (server spec 準拠)', () {
    test('has_issue と status_changed_at をパースする', () {
      final c = WatchedClient.fromJson({
        'id': 'c-1',
        'display_name': '母',
        'status': 'ALERT',
        'status_changed_at': '2026-07-16T12:00:00.000Z',
        'has_issue': true,
        'property_tag': null,
      });
      expect(c.id, 'c-1');
      expect(c.displayName, '母');
      expect(c.status, ClientStatus.alert);
      expect(c.hasIssue, isTrue);
      expect(c.statusChangedAt, DateTime.utc(2026, 7, 16, 12, 0));
    });

    test('has_issue 省略時は false', () {
      final c = WatchedClient.fromJson({
        'id': 'c-2',
        'display_name': '父',
        'status': 'ALIVE',
      });
      expect(c.hasIssue, isFalse);
    });
  });

  group('StatusTransition (server spec 準拠)', () {
    test('changed_at フィールドと null from をパースする', () {
      final t = StatusTransition.fromJson({
        'from': null, // 初回遷移
        'to': 'WATCH',
        'changed_at': '2026-07-16T09:30:00.000Z',
      });
      expect(t.from, ClientStatus.unknown);
      expect(t.to, ClientStatus.watch);
      expect(t.at, DateTime.utc(2026, 7, 16, 9, 30));
    });
  });

  group('ProvisionResult (逆方向ペアリング)', () {
    test('provision レスポンスをパースする', () {
      final p = ProvisionResult.fromJson({
        'provision_id': 'prov-1',
        'claim_code': 'abcdef1234567890',
        'fallback_code': '123456',
        'claim_secret': 'secret-xyz',
        'expires_in_minutes': 30,
      });
      expect(p.provisionId, 'prov-1');
      expect(p.claimCode, 'abcdef1234567890');
      expect(p.fallbackCode, '123456');
      expect(p.claimSecret, 'secret-xyz');
      expect(p.expiresInMinutes, 30);
    });

    test('expires_in_minutes 省略時は 30 にフォールバックする', () {
      final p = ProvisionResult.fromJson({
        'provision_id': 'prov-2',
        'claim_code': 'code',
        'fallback_code': '000000',
        'claim_secret': 'sec',
      });
      expect(p.expiresInMinutes, 30);
    });
  });

  group('ClaimStatus (逆方向ペアリング)', () {
    test('claim 前は claimed=false でトークンは null', () {
      final s = ClaimStatus.fromJson({'claimed': false});
      expect(s.claimed, isFalse);
      expect(s.deviceToken, isNull);
      expect(s.clientId, isNull);
    });

    test('claim 後は device_token と client_id を持つ', () {
      final s = ClaimStatus.fromJson({
        'claimed': true,
        'device_token': 'jwt-token',
        'client_id': 'c-1',
      });
      expect(s.claimed, isTrue);
      expect(s.deviceToken, 'jwt-token');
      expect(s.clientId, 'c-1');
    });
  });

  group('InviteResult / InviteStatus (複数見守り)', () {
    test('invite レスポンスをパースする', () {
      final r = InviteResult.fromJson({
        'invite_id': 'inv-1',
        'invite_code': 'long-invite-token',
        'fallback_code': '654321',
        'expires_in_minutes': 30,
      });
      expect(r.inviteId, 'inv-1');
      expect(r.inviteCode, 'long-invite-token');
      expect(r.fallbackCode, '654321');
      expect(r.expiresInMinutes, 30);
    });

    test('expires_in_minutes 省略時は 30 にフォールバックする', () {
      final r = InviteResult.fromJson({
        'invite_id': 'inv-2',
        'invite_code': 'x',
        'fallback_code': '000000',
      });
      expect(r.expiresInMinutes, 30);
    });

    test('参加前は joined=false で watcher_name は null', () {
      final s = InviteStatus.fromJson({'joined': false});
      expect(s.joined, isFalse);
      expect(s.watcherName, isNull);
    });

    test('参加後は joined=true で watcher_name を持つ', () {
      final s = InviteStatus.fromJson({
        'joined': true,
        'watcher_name': '花子',
      });
      expect(s.joined, isTrue);
      expect(s.watcherName, '花子');
    });
  });

  group('ClientLoginResult (機種変更継続)', () {
    test('login レスポンスをパースする', () {
      final r = ClientLoginResult.fromJson({
        'client_id': 'c-1',
        'device_id': 'dev-9',
        'device_token': 'jwt-device-token',
      });
      expect(r.clientId, 'c-1');
      expect(r.deviceId, 'dev-9');
      expect(r.deviceToken, 'jwt-device-token');
    });
  });

  group('Stamp (server spec 準拠)', () {
    test('from_watcher のスタンプをパースする', () {
      final s = Stamp.fromJson({
        'id': 124, // サーバーは bigserial（数値でも文字列でも受ける）
        'stamp': 'fine',
        'direction': 'from_watcher',
        'sender_name': '太郎',
        'created_at': '2026-07-17T10:00:00.000Z',
      });
      expect(s.id, '124');
      expect(s.stamp, 'fine');
      expect(s.direction, StampDirection.fromWatcher);
      expect(s.senderName, '太郎');
      expect(s.createdAt, DateTime.utc(2026, 7, 17, 10, 0));
      expect(s.kind.label, '元気');
    });

    test('from_client のスタンプをパースする', () {
      final s = Stamp.fromJson({
        'id': '120',
        'stamp': 'bad',
        'direction': 'from_client',
        'sender_name': 'おばあちゃん',
        'created_at': '2026-07-17T09:00:00.000Z',
      });
      expect(s.direction, StampDirection.fromClient);
      expect(s.kind.label, 'ダメ');
    });

    test('カタログのコードと表示が対称であること', () {
      for (final k in StampKind.all) {
        expect(StampKind.of(k.code), same(k));
      }
      expect(StampKind.of('fine').label, '元気');
      expect(StampKind.of('not_well').label, '調子悪い');
      expect(StampKind.of('bad').label, 'ダメ');
    });

    test('未知のスタンプコードは汎用表示にフォールバックする（将来の種類追加）', () {
      final k = StampKind.of('super_new_stamp');
      expect(k.code, 'super_new_stamp');
      expect(k.label, 'スタンプ');
      expect(k.emoji, isNotEmpty);
    });
  });

  group('匿名ウォッチャー install_id', () {
    test('生成される install_id は UUIDv4 形式（version/variant ビット）', () {
      for (var i = 0; i < 50; i++) {
        expect(Prefs.newUuidV4(), matches(_uuidV4Re));
      }
    });

    test('連続生成した install_id は一意である', () {
      final ids = List.generate(200, (_) => Prefs.newUuidV4());
      expect(ids.toSet().length, ids.length);
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

    test('active SOS レスポンス（id / client_name / location_captured_at）をパースする',
        () {
      // GET /v1/clients/:id/sos/active の確定レスポンス形。
      final inc = SosIncident.fromJson(<String, dynamic>{
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'client_id': '660e8400-e29b-41d4-a716-446655440001',
        'client_name': '母',
        'latitude': 35.68,
        'longitude': 139.77,
        'battery_level': 42,
        'fired_at': '2026-07-18T08:30:00.000Z',
        'resolved_at': null,
        'location_captured_at': '2026-07-18T08:25:00.000Z',
      });
      expect(inc.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(inc.clientName, '母');
      expect(inc.batteryLevel, 42);
      expect(inc.hasLocation, isTrue);
      expect(inc.isResolved, isFalse);
    });

    test('incident_id キー（フォールバック）でも id を取得できる', () {
      final inc = SosIncident.fromJson(<String, dynamic>{
        'incident_id': 'inc-1',
        'battery_level': 10,
        'fired_at': '2026-07-18T08:30:00.000Z',
      });
      expect(inc.id, 'inc-1');
      expect(inc.clientId, ''); // active 応答に client_id が無い場合の既定
    });
  });

  group('MockApiClient SOS 確認→クリア導線', () {
    test('SOS 発報中のサンプル（c-3）はアクティブ SOS を返す', () async {
      final api = MockApiClient();
      final inc = await api.getActiveSos(watcherToken: 't', clientId: 'c-3');
      expect(inc, isNotNull);
      expect(inc!.clientId, 'c-3');
      expect(inc.isResolved, isFalse);
    });

    test('SOS 未発報のクライアントは null（404 相当）を返す', () async {
      final api = MockApiClient();
      final inc = await api.getActiveSos(watcherToken: 't', clientId: 'c-1');
      expect(inc, isNull);
    });

    test('resolve 後はアクティブ SOS が消え、ステータスが ALIVE に戻る', () async {
      final api = MockApiClient();
      final inc = await api.getActiveSos(watcherToken: 't', clientId: 'c-3');
      await api.resolveSos(watcherToken: 't', incidentId: inc!.id);

      final after = await api.getActiveSos(watcherToken: 't', clientId: 'c-3');
      expect(after, isNull);

      final clients = await api.listClients(watcherToken: 't');
      final c3 = clients.firstWhere((c) => c.id == 'c-3');
      expect(c3.status, ClientStatus.alive);
    });
  });

  group('DailyActivity 活動量', () {
    test('fromJson が集計フィールドをパースする', () {
      final a = DailyActivity.fromJson(const {
        'date': '2026-07-18',
        'screen_on_count': 47,
        'app_usage_slots': 12,
        'movement_slots': 8,
        'heartbeat_count': 72,
      });
      expect(a.date, DateTime(2026, 7, 18));
      expect(a.screenOnCount, 47);
      expect(a.appUsageSlots, 12);
      expect(a.movementSlots, 8);
      expect(a.heartbeatCount, 72);
      expect(a.hasActivity, isTrue);
    });

    test('欠損フィールドは 0 にフォールバックし hasActivity=false', () {
      final a = DailyActivity.fromJson(const {'date': '2026-07-18'});
      expect(a.screenOnCount, 0);
      expect(a.movementSlots, 0);
      expect(a.hasActivity, isFalse);
    });

    test('スロット数→概算時間の表示（0 / 1 / 4 / 5 スロット）', () {
      DailyActivity make(int slots) => DailyActivity(
            date: DateTime(2026, 7, 18),
            screenOnCount: 0,
            appUsageSlots: slots,
            movementSlots: slots,
            heartbeatCount: 0,
          );
      expect(make(0).movementDuration, '—'); // 0 は「—」
      expect(make(1).movementDuration, '約15分'); // 15分
      expect(make(4).movementDuration, '約1時間'); // 60分ちょうど
      expect(make(5).movementDuration, '約1時間15分'); // 75分
      expect(make(8).appUsageDuration, '約2時間'); // 120分
    });
  });

  group('MockApiClient 活動量', () {
    test('活発なサンプル（c-1）は2日分の活動を返す', () async {
      final api = MockApiClient();
      final days =
          await api.getClientActivity(watcherToken: 't', clientId: 'c-1');
      expect(days.length, 2);
      expect(days.first.hasActivity, isTrue);
      expect(days.first.screenOnCount, 47);
    });

    test('days=1 で1日分に絞られる', () async {
      final api = MockApiClient();
      final days = await api
          .getClientActivity(watcherToken: 't', clientId: 'c-1', days: 1);
      expect(days.length, 1);
    });
  });

  group('LocationCache 移動判定（活動量シグナル）', () {
    test('しきい値は 100m、キャッシュ鮮度上限は 24 時間', () {
      expect(LocationCache.movementThresholdMeters, 100);
      expect(LocationCache.maxCacheAge, const Duration(hours: 24));
    });

    test('近距離（約11m）はしきい値未満＝移動なし判定', () {
      // 緯度0.0001度 ≈ 11m
      final d = Geolocator.distanceBetween(35.0000, 139.0, 35.0001, 139.0);
      expect(d < LocationCache.movementThresholdMeters, isTrue);
    });

    test('遠距離（約111m）はしきい値以上＝移動あり判定', () {
      // 緯度0.001度 ≈ 111m
      final d = Geolocator.distanceBetween(35.000, 139.0, 35.001, 139.0);
      expect(d >= LocationCache.movementThresholdMeters, isTrue);
    });
  });
}
