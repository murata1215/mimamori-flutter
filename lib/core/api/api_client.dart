import '../models/heartbeat.dart';
import '../models/sos_incident.dart';
import '../models/watched_client.dart';

/// サーバー API の抽象インターフェース。
/// 実サーバー版 (`HttpApiClient`) とモック版 (`MockApiClient`) が実装する。
abstract class ApiClient {
  // --- 認証・ペアリング ---
  Future<String> registerWatcher({
    required String email,
    required String password,
    required String displayName,
  });

  Future<String> loginWatcher({
    required String email,
    required String password,
  });

  /// ウォッチャーがペアリングコードを発行（TTL 15分）。
  Future<PairingCode> createPairingCode();

  /// クライアント端末がコードを提出してペアリング。
  /// → client_id とデバイストークンを返し、同意も記録する。
  Future<PairResult> pairClient({
    required String code,
    required String displayName,
    required String consentVersion,
  });

  // --- クライアント端末 ---
  Future<void> sendHeartbeats({
    required String clientToken,
    required List<Heartbeat> beats,
    required DeliveryStats stats,
  });

  Future<SosIncident> sendSos({
    required String clientToken,
    double? lat,
    double? lng,
    required int batteryLevel,
  });

  Future<void> confirmAlive({required String clientToken});

  Future<void> reportPermissionHealth({
    required String clientToken,
    required Map<String, bool> permissions,
  });

  // --- ウォッチャー ---
  Future<List<WatchedClient>> listClients({required String watcherToken});

  Future<List<StatusTransition>> statusHistory({
    required String watcherToken,
    required String clientId,
  });

  Future<SosIncident?> getSos({
    required String watcherToken,
    required String incidentId,
  });

  Future<void> resolveSos({
    required String watcherToken,
    required String incidentId,
  });
}

class PairingCode {
  final String code;
  final DateTime expiresAt;
  const PairingCode(this.code, this.expiresAt);
}

class PairResult {
  final String clientId;
  final String deviceToken;
  const PairResult(this.clientId, this.deviceToken);
}

/// API 例外。
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});
  @override
  String toString() => 'ApiException($statusCode): $message';
}
