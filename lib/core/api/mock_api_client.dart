import 'dart:async';
import 'dart:math';

import '../models/client_status.dart';
import '../models/daily_activity.dart';
import '../models/heartbeat.dart';
import '../models/sos_incident.dart';
import '../models/stamp.dart';
import '../models/watched_client.dart';
import 'api_client.dart';

/// サーバー未接続でも全画面を動作確認するためのインメモリ疑似サーバー。
///
/// 判定エンジンは本来サーバー側だが、モックでは簡易な状態遷移を再現し、
/// ウォッチャー UI・通知フローの確認に使える。
class MockApiClient implements ApiClient {
  final _rand = Random();
  final Map<String, WatchedClient> _clients = {};
  final Map<String, List<StatusTransition>> _history = {};
  final Map<String, SosIncident> _sos = {};

  MockApiClient() {
    // デモ用に見守り対象を投入（モックモードでのみ表示されるサンプル）
    _seed('c-1', '（サンプル）お母さん', ClientStatus.alive);
    _seed('c-2', '（サンプル）お父さん', ClientStatus.watch);
    // SOS 発報中のサンプル（確認→クリア導線の動作確認用）
    _seed('c-3', '（サンプル）祖母', ClientStatus.sos);
    _sos['sos-demo'] = SosIncident(
      id: 'sos-demo',
      clientId: 'c-3',
      clientName: '（サンプル）祖母',
      latitude: 35.681236,
      longitude: 139.767125,
      batteryLevel: 42,
      firedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );

    // デモ用スタンプ履歴（ウォッチャー詳細/クライアント受信表示の確認用）
    _clientStamps['c-1'] = [
      Stamp(
        id: 's-2',
        stamp: 'fine',
        direction: StampDirection.fromClient,
        senderName: '（サンプル）お母さん',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Stamp(
        id: 's-1',
        stamp: 'fine',
        direction: StampDirection.fromWatcher,
        senderName: 'あなた',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ];
    _myStamps.add(Stamp(
      id: 's-0',
      stamp: 'fine',
      direction: StampDirection.fromWatcher,
      senderName: '（サンプル）太郎',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ));
  }

  void _seed(String id, String name, ClientStatus status) {
    final now = DateTime.now();
    _clients[id] = WatchedClient(
      id: id,
      displayName: name,
      status: status,
      statusChangedAt: now.subtract(const Duration(hours: 2)),
      // 最終操作＝約40分前、最終通信＝約5分前（画面確認用のデモ値）。
      lastActivityAt: now.subtract(const Duration(minutes: 40)),
      lastSeenAt: now.subtract(const Duration(minutes: 5)),
    );
    _history[id] = [
      StatusTransition(
        from: ClientStatus.watch,
        to: ClientStatus.alive,
        at: DateTime.now().subtract(const Duration(hours: 6)),
      ),
    ];
  }

  Future<T> _delayed<T>(T value) =>
      Future.delayed(const Duration(milliseconds: 300), () => value);

  AuthResult get _mockAuth => const AuthResult(
        watcherId: 'mock-watcher-id',
        accessToken: 'mock-watcher-token',
        refreshToken: 'mock-refresh-token',
      );

  @override
  Future<AuthResult> registerWatcher({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _delayed(_mockAuth);

  @override
  Future<AuthResult> loginWatcher({
    required String email,
    required String password,
  }) =>
      _delayed(_mockAuth);

  @override
  Future<AuthResult> refreshWatcherToken({required String refreshToken}) =>
      _delayed(_mockAuth);

  @override
  Future<AuthResult> registerWatcherDevice({
    required String installId,
    required String displayName,
    required String platform,
  }) =>
      _delayed(_mockAuth);

  @override
  Future<void> registerWatcherEmail({
    required String watcherToken,
    required String email,
    required String password,
  }) =>
      _delayed(null);

  @override
  Future<void> updateWatcherDisplayName({
    required String watcherToken,
    required String displayName,
  }) =>
      _delayed(null);

  int _claimPolls = 0;

  @override
  Future<ProvisionResult> createProvision({
    required String platform,
    required String consentVersion,
    String? appVersion,
    String? fcmToken,
  }) {
    _claimPolls = 0;
    final fallback = (100000 + _rand.nextInt(900000)).toString(); // 6桁
    return _delayed(ProvisionResult(
      provisionId: 'prov-${_rand.nextInt(10000)}',
      claimCode: 'mock-claim-${_rand.nextInt(1000000)}',
      fallbackCode: fallback,
      claimSecret: 'mock-secret-${_rand.nextInt(1000000)}',
      expiresInMinutes: 30,
    ));
  }

  @override
  Future<ClaimStatus> getClaimStatus({required String claimSecret}) {
    // デモ用: 数回ポーリングすると「ウォッチャーが登録した」ことにして先へ進める。
    _claimPolls++;
    if (_claimPolls >= 2) {
      return _delayed(ClaimStatus(
        claimed: true,
        deviceToken: 'mock-device-token',
        clientId: 'c-self-${_rand.nextInt(10000)}',
      ));
    }
    return _delayed(const ClaimStatus(claimed: false));
  }

  @override
  Future<String> claimClient({
    required String watcherToken,
    required String code,
    required String displayName,
  }) {
    final id = 'c-${_rand.nextInt(10000)}';
    _seed(id, displayName, ClientStatus.alive);
    return _delayed(id);
  }

  int _invitePolls = 0;
  final List<String> _myWatchers = ['（サンプル）太郎'];

  @override
  Future<InviteResult> createInviteCode({required String clientToken}) {
    _invitePolls = 0;
    final fallback = (100000 + _rand.nextInt(900000)).toString(); // 6桁
    return _delayed(InviteResult(
      inviteId: 'inv-${_rand.nextInt(10000)}',
      inviteCode: 'mock-invite-${_rand.nextInt(1000000)}',
      fallbackCode: fallback,
      expiresInMinutes: 30,
    ));
  }

  @override
  Future<InviteStatus> getInviteStatus({
    required String clientToken,
    required String inviteId,
  }) {
    // デモ用: 数回ポーリングすると「新しい見守り人が参加した」ことにする。
    _invitePolls++;
    if (_invitePolls >= 2) {
      const name = '（サンプル）花子';
      if (!_myWatchers.contains(name)) _myWatchers.add(name);
      return _delayed(const InviteStatus(joined: true, watcherName: name));
    }
    return _delayed(const InviteStatus(joined: false));
  }

  @override
  Future<String> joinClient({
    required String watcherToken,
    required String code,
    required String displayName,
  }) {
    // 既存クライアント（サンプル1人目）に watch_link を足す想定。
    return _delayed('c-1');
  }

  @override
  Future<List<String>> listMyWatchers({required String clientToken}) =>
      _delayed(List<String>.from(_myWatchers));

  @override
  Future<void> registerClientEmail({
    required String clientToken,
    required String email,
    required String password,
  }) =>
      _delayed(null);

  @override
  Future<ClientLoginResult> loginClient({
    required String email,
    required String password,
    required String platform,
    required String consentVersion,
    String? appVersion,
    String? fcmToken,
  }) =>
      _delayed(ClientLoginResult(
        clientId: 'c-self-mock',
        deviceId: 'dev-${_rand.nextInt(10000)}',
        deviceToken: 'mock-device-token',
      ));

  @override
  Future<void> sendHeartbeats({
    required String clientToken,
    required List<Heartbeat> beats,
    required DeliveryStats stats,
  }) =>
      _delayed(null);

  @override
  Future<String> sendSos({
    required String clientToken,
    double? lat,
    double? lng,
    required int batteryLevel,
    DateTime? capturedAt,
  }) {
    final id = 'sos-${_rand.nextInt(10000)}';
    final incident = SosIncident(
      id: id,
      clientId: 'self',
      latitude: lat,
      longitude: lng,
      batteryLevel: batteryLevel,
      firedAt: DateTime.now(),
    );
    _sos[id] = incident;
    return _delayed(id);
  }

  @override
  Future<void> confirmAlive({required String clientToken}) => _delayed(null);

  @override
  Future<void> reportPermissionHealth({
    required String clientToken,
    required List<String> issues,
  }) =>
      _delayed(null);

  @override
  Future<void> updateDeviceFcmToken({
    required String clientToken,
    required String fcmToken,
  }) =>
      _delayed(null);

  @override
  Future<void> updateWatcherFcmToken({
    required String watcherToken,
    required String fcmToken,
  }) =>
      _delayed(null);

  @override
  Future<List<WatchedClient>> listClients({required String watcherToken}) =>
      _delayed(_clients.values.toList());

  @override
  Future<List<StatusTransition>> statusHistory({
    required String watcherToken,
    required String clientId,
  }) =>
      _delayed(_history[clientId] ?? const []);

  @override
  Future<List<DailyActivity>> getClientActivity({
    required String watcherToken,
    required String clientId,
    int days = 3,
  }) {
    // サンプル: c-1（活発）/ c-3（少なめ）で見え方を変える。おととい分は欠損。
    final active = clientId != 'c-3';
    final today = DateTime.now();
    DateTime dayOnly(int ago) =>
        DateTime(today.year, today.month, today.day - ago);
    final result = <DailyActivity>[
      DailyActivity(
        date: dayOnly(0),
        screenOnCount: active ? 47 : 12,
        appUsageSlots: active ? 12 : 3,
        movementSlots: active ? 8 : 2,
        heartbeatCount: active ? 72 : 60,
      ),
      DailyActivity(
        date: dayOnly(1),
        screenOnCount: active ? 35 : 8,
        appUsageSlots: active ? 9 : 2,
        movementSlots: active ? 5 : 1,
        heartbeatCount: active ? 68 : 55,
      ),
      // おととい（ago=2）はデータなしで「記録がありません」表示を確認できる。
    ];
    return _delayed(result.take(days.clamp(1, 7)).toList());
  }

  @override
  Future<SosIncident?> getSos({
    required String watcherToken,
    required String incidentId,
  }) =>
      _delayed(_sos[incidentId]);

  @override
  Future<SosIncident?> getActiveSos({
    required String watcherToken,
    required String clientId,
  }) {
    SosIncident? active;
    for (final s in _sos.values) {
      if (s.clientId == clientId && !s.isResolved) {
        active = s;
        break;
      }
    }
    return _delayed(active);
  }

  @override
  Future<void> resolveSos({
    required String watcherToken,
    required String incidentId,
  }) async {
    final s = _sos[incidentId];
    if (s != null) {
      _sos[incidentId] = SosIncident(
        id: s.id,
        clientId: s.clientId,
        clientName: s.clientName,
        latitude: s.latitude,
        longitude: s.longitude,
        batteryLevel: s.batteryLevel,
        firedAt: s.firedAt,
        resolvedAt: DateTime.now(),
      );
      // resolve 後はサーバー同様ステータスを ALIVE に戻す（モック再現）。
      final c = _clients[s.clientId];
      if (c != null && c.status == ClientStatus.sos) {
        _clients[s.clientId] = c.copyWith(
          status: ClientStatus.alive,
          statusChangedAt: DateTime.now(),
        );
      }
    }
    return _delayed(null);
  }

  @override
  Future<void> unwatchClient({
    required String watcherToken,
    required String clientId,
  }) {
    // 見守り紐づけを解除＝一覧から除去（モックでは client レコードごと消す再現）。
    _clients.remove(clientId);
    _history.remove(clientId);
    return _delayed(null);
  }

  // --- スタンプ（インメモリ） ---
  final Map<String, List<Stamp>> _clientStamps = {};
  final List<Stamp> _myStamps = [];
  int _stampSeq = 100;

  @override
  Future<String> sendStampAsClient({
    required String clientToken,
    required String stamp,
  }) {
    final s = Stamp(
      id: 's-${_stampSeq++}',
      stamp: stamp,
      direction: StampDirection.fromClient,
      senderName: 'あなた',
      createdAt: DateTime.now(),
    );
    // 同一端末デモ: 自分の履歴と、ウォッチャー側サンプル1人目の履歴に反映
    _myStamps.insert(0, s);
    _clientStamps.putIfAbsent('c-1', () => []).insert(0, s);
    return _delayed(s.id);
  }

  @override
  Future<String> sendStampAsWatcher({
    required String watcherToken,
    required String clientId,
    required String stamp,
  }) {
    final s = Stamp(
      id: 's-${_stampSeq++}',
      stamp: stamp,
      direction: StampDirection.fromWatcher,
      senderName: 'あなた',
      createdAt: DateTime.now(),
    );
    _clientStamps.putIfAbsent(clientId, () => []).insert(0, s);
    // 同一端末デモ: クライアント側の受信表示にも反映
    _myStamps.insert(0, s);
    return _delayed(s.id);
  }

  @override
  Future<List<Stamp>> listMyStamps({
    required String clientToken,
    int limit = 50,
  }) =>
      _delayed(_myStamps.take(limit).toList());

  @override
  Future<List<Stamp>> listClientStamps({
    required String watcherToken,
    required String clientId,
    int limit = 50,
  }) =>
      _delayed((_clientStamps[clientId] ?? const []).take(limit).toList());

  // --- デモ操作（UI から状態を切替えて通知フローを確認する用） ---
  void debugSetStatus(String clientId, ClientStatus status) {
    final c = _clients[clientId];
    if (c != null) {
      _history.putIfAbsent(clientId, () => []).add(StatusTransition(
            from: c.status,
            to: status,
            at: DateTime.now(),
          ));
      _clients[clientId] = c.copyWith(
        status: status,
        statusChangedAt: DateTime.now(),
      );
    }
  }
}
