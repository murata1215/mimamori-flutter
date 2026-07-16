import 'package:dio/dio.dart';

import '../models/heartbeat.dart';
import '../models/sos_incident.dart';
import '../models/watched_client.dart';
import 'api_client.dart';

/// 実サーバー向け REST 実装（server spec の API に準拠）。
/// 全通信 TLS。認証は JWT / デバイストークン。
class HttpApiClient implements ApiClient {
  HttpApiClient(String baseUrl)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          contentType: 'application/json',
        ));

  final Dio _dio;

  Options _auth(String token) => Options(headers: {
        'Authorization': 'Bearer $token',
      });

  Never _rethrow(DioException e) {
    throw ApiException(
      e.response?.data?.toString() ?? e.message ?? 'network error',
      statusCode: e.response?.statusCode,
    );
  }

  @override
  Future<String> registerWatcher({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final r = await _dio.post('/v1/watchers', data: {
        'email': email,
        'password': password,
        'display_name': displayName,
      });
      return r.data['token'] as String;
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<String> loginWatcher({
    required String email,
    required String password,
  }) async {
    try {
      final r = await _dio.post('/v1/watchers/login', data: {
        'email': email,
        'password': password,
      });
      return r.data['token'] as String;
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<PairingCode> createPairingCode() async {
    // ウォッチャートークンは実際にはヘッダに必要。呼び出し側で dio 拡張予定。
    try {
      final r = await _dio.post('/v1/pairing-codes');
      return PairingCode(
        r.data['code'] as String,
        DateTime.parse(r.data['expires_at'] as String),
      );
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<PairResult> pairClient({
    required String code,
    required String displayName,
    required String consentVersion,
  }) async {
    try {
      final r = await _dio.post('/v1/clients/pair', data: {
        'code': code,
        'display_name': displayName,
        'consent_version': consentVersion,
      });
      return PairResult(
        r.data['client_id'] as String,
        r.data['device_token'] as String,
      );
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> sendHeartbeats({
    required String clientToken,
    required List<Heartbeat> beats,
    required DeliveryStats stats,
  }) async {
    try {
      await _dio.post(
        '/v1/heartbeats',
        data: {
          'heartbeats': beats.map((b) => b.toJson()).toList(),
          'delivery_stats': stats.toJson(),
        },
        options: _auth(clientToken),
      );
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<SosIncident> sendSos({
    required String clientToken,
    double? lat,
    double? lng,
    required int batteryLevel,
  }) async {
    try {
      final r = await _dio.post(
        '/v1/sos',
        data: {
          'lat': ?lat,
          'lng': ?lng,
          'battery_level': batteryLevel,
        },
        options: _auth(clientToken),
      );
      return SosIncident.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> confirmAlive({required String clientToken}) async {
    try {
      await _dio.post('/v1/confirm-alive', options: _auth(clientToken));
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> reportPermissionHealth({
    required String clientToken,
    required Map<String, bool> permissions,
  }) async {
    try {
      await _dio.post(
        '/v1/permission-health',
        data: {'permissions': permissions},
        options: _auth(clientToken),
      );
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<List<WatchedClient>> listClients({required String watcherToken}) async {
    try {
      final r = await _dio.get('/v1/clients', options: _auth(watcherToken));
      final list = (r.data['clients'] as List<dynamic>);
      return list
          .map((e) => WatchedClient.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<List<StatusTransition>> statusHistory({
    required String watcherToken,
    required String clientId,
  }) async {
    try {
      final r = await _dio.get(
        '/v1/clients/$clientId/status-history',
        options: _auth(watcherToken),
      );
      final list = (r.data['transitions'] as List<dynamic>);
      return list
          .map((e) => StatusTransition.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<SosIncident?> getSos({
    required String watcherToken,
    required String incidentId,
  }) async {
    try {
      final r =
          await _dio.get('/v1/sos/$incidentId', options: _auth(watcherToken));
      return SosIncident.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null; // resolved/purge 後
      _rethrow(e);
    }
  }

  @override
  Future<void> resolveSos({
    required String watcherToken,
    required String incidentId,
  }) async {
    try {
      await _dio.post(
        '/v1/sos/$incidentId/resolve',
        options: _auth(watcherToken),
      );
    } on DioException catch (e) {
      _rethrow(e);
    }
  }
}
