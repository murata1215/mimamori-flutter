import 'dart:async';
import 'dart:math';

import '../models/client_status.dart';
import '../models/heartbeat.dart';
import '../models/sos_incident.dart';
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
  String? _lastPairCode;

  MockApiClient() {
    // デモ用に見守り対象を2名投入（モックモードでのみ表示されるサンプル）
    _seed('c-1', '（サンプル）お母さん', ClientStatus.alive);
    _seed('c-2', '（サンプル）お父さん', ClientStatus.watch);
  }

  void _seed(String id, String name, ClientStatus status) {
    _clients[id] = WatchedClient(
      id: id,
      displayName: name,
      status: status,
      statusChangedAt: DateTime.now().subtract(const Duration(hours: 2)),
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

  @override
  Future<String> registerWatcher({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _delayed('mock-watcher-token');

  @override
  Future<String> loginWatcher({
    required String email,
    required String password,
  }) =>
      _delayed('mock-watcher-token');

  @override
  Future<PairingCode> createPairingCode() {
    _lastPairCode =
        (100000 + _rand.nextInt(900000)).toString(); // 6桁
    return _delayed(PairingCode(
      _lastPairCode!,
      DateTime.now().add(const Duration(minutes: 15)),
    ));
  }

  @override
  Future<PairResult> pairClient({
    required String code,
    required String displayName,
    required String consentVersion,
  }) {
    final id = 'c-${_rand.nextInt(10000)}';
    _seed(id, displayName, ClientStatus.alive);
    return _delayed(PairResult(id, 'mock-device-token'));
  }

  @override
  Future<void> sendHeartbeats({
    required String clientToken,
    required List<Heartbeat> beats,
    required DeliveryStats stats,
  }) =>
      _delayed(null);

  @override
  Future<SosIncident> sendSos({
    required String clientToken,
    double? lat,
    double? lng,
    required int batteryLevel,
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
    return _delayed(incident);
  }

  @override
  Future<void> confirmAlive({required String clientToken}) => _delayed(null);

  @override
  Future<void> reportPermissionHealth({
    required String clientToken,
    required Map<String, bool> permissions,
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
  Future<SosIncident?> getSos({
    required String watcherToken,
    required String incidentId,
  }) =>
      _delayed(_sos[incidentId]);

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
    }
    return _delayed(null);
  }

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
