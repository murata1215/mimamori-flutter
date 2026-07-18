import 'package:dio/dio.dart';

import '../models/heartbeat.dart';
import '../models/sos_incident.dart';
import '../models/stamp.dart';
import '../models/watched_client.dart';
import '../storage/prefs.dart';
import 'api_client.dart';

/// 実サーバー向け REST 実装（server spec の API に準拠）。
/// 全通信 TLS。認証は JWT / デバイストークン。
class HttpApiClient implements ApiClient {
  HttpApiClient(String baseUrl, {Prefs? prefs})
      : _prefs = prefs,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          contentType: 'application/json',
        )) {
    // ウォッチャー access トークン失効(401)時に refresh で自動再発行してリトライ。
    if (_prefs != null) {
      _dio.interceptors.add(InterceptorsWrapper(onError: _onError));
    }
  }

  final Dio _dio;
  final Prefs? _prefs;
  bool _refreshing = false;

  Options _auth(String token) => Options(headers: {
        'Authorization': 'Bearer $token',
      });

  /// 401 を捕まえ、対象がウォッチャー access トークンでの認証なら
  /// refresh トークンで再発行し、元リクエストを1回だけ再試行する。
  Future<void> _onError(
    DioException e,
    ErrorInterceptorHandler handler,
  ) async {
    final prefs = _prefs;
    final req = e.requestOptions;
    final currentWatcher = prefs?.watcherToken;
    final refresh = prefs?.watcherRefreshToken;

    final isWatcherRequest = currentWatcher != null &&
        req.headers['Authorization'] == 'Bearer $currentWatcher';

    if (e.response?.statusCode == 401 &&
        prefs != null &&
        refresh != null &&
        isWatcherRequest &&
        !_refreshing &&
        req.extra['__retried'] != true) {
      _refreshing = true;
      try {
        final r = await _dio.post('/v1/watchers/refresh', data: {
          'refresh_token': refresh,
        });
        final access = r.data['access_token'] as String;
        final newRefresh = r.data['refresh_token'] as String;
        await prefs.setWatcherToken(access);
        await prefs.setWatcherRefreshToken(newRefresh);

        req.headers['Authorization'] = 'Bearer $access';
        req.extra['__retried'] = true;
        final clone = await _dio.fetch(req);
        return handler.resolve(clone);
      } catch (_) {
        // refresh も失敗。匿名ウォッチャーなら install_id で無言に再登録して復旧する
        // （ログイン画面に戻さない）。復旧できなければトークン破棄。
        final recovered = await _recoverAnonymousSession(prefs);
        if (recovered != null) {
          try {
            req.headers['Authorization'] = 'Bearer $recovered';
            req.extra['__retried'] = true;
            final clone = await _dio.fetch(req);
            return handler.resolve(clone);
          } catch (_) {
            // 再試行も失敗 → 通常のエラー伝播にフォールスルー
          }
        } else {
          await prefs.setWatcherToken(null);
          await prefs.setWatcherRefreshToken(null);
        }
      } finally {
        _refreshing = false;
      }
    }
    handler.next(e);
  }

  /// 匿名ウォッチャー（メール未登録）を install_id で再登録し、新トークンを保存して返す。
  /// 名前が未保存など再登録できない場合は null。
  Future<String?> _recoverAnonymousSession(Prefs prefs) async {
    final name = prefs.watcherDisplayName;
    if (name == null || name.isEmpty) return null;
    try {
      final r = await _dio.post('/v1/watchers/register-device', data: {
        'install_id': prefs.watcherInstallId,
        'display_name': name,
        'platform': 'android',
      });
      final access = r.data['access_token'] as String;
      final refresh = r.data['refresh_token'] as String;
      final wid = r.data['watcher_id'] as String?;
      await prefs.setWatcherToken(access);
      await prefs.setWatcherRefreshToken(refresh);
      if (wid != null) await prefs.setWatcherId(wid);
      return access;
    } catch (_) {
      return null;
    }
  }

  Never _rethrow(DioException e) {
    throw ApiException(
      e.response?.data?.toString() ?? e.message ?? 'network error',
      statusCode: e.response?.statusCode,
    );
  }

  AuthResult _authResult(Map<String, dynamic> data) => AuthResult(
        watcherId: data['watcher_id'] as String?,
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );

  @override
  Future<AuthResult> registerWatcher({
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
      return _authResult(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<AuthResult> loginWatcher({
    required String email,
    required String password,
  }) async {
    try {
      final r = await _dio.post('/v1/watchers/login', data: {
        'email': email,
        'password': password,
      });
      return _authResult(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<AuthResult> refreshWatcherToken({required String refreshToken}) async {
    try {
      final r = await _dio.post('/v1/watchers/refresh', data: {
        'refresh_token': refreshToken,
      });
      return _authResult(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<AuthResult> registerWatcherDevice({
    required String installId,
    required String displayName,
    required String platform,
  }) async {
    try {
      final r = await _dio.post('/v1/watchers/register-device', data: {
        'install_id': installId,
        'display_name': displayName,
        'platform': platform,
      });
      return _authResult(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> registerWatcherEmail({
    required String watcherToken,
    required String email,
    required String password,
  }) async {
    try {
      await _dio.post(
        '/v1/watchers/me/email',
        data: {'email': email, 'password': password},
        options: _auth(watcherToken),
      );
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> updateWatcherDisplayName({
    required String watcherToken,
    required String displayName,
  }) async {
    try {
      await _dio.patch(
        '/v1/watchers/me',
        data: {'display_name': displayName},
        options: _auth(watcherToken),
      );
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<ProvisionResult> createProvision({
    required String platform,
    required String consentVersion,
    String? appVersion,
    String? fcmToken,
  }) async {
    try {
      final r = await _dio.post('/v1/provisions', data: {
        'platform': platform,
        'consent_version': consentVersion,
        'app_version': ?appVersion,
        'fcm_token': ?fcmToken,
      });
      return ProvisionResult.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<ClaimStatus> getClaimStatus({required String claimSecret}) async {
    try {
      // claim_secret を Bearer として送る（JWT ではない平文シークレット）。
      final r = await _dio.get(
        '/v1/provisions/me',
        options: _auth(claimSecret),
      );
      return ClaimStatus.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // provision 期限切れ（404 expired）はポーリング側で再 provision する。
      if (e.response?.statusCode == 404) {
        return const ClaimStatus(claimed: false);
      }
      _rethrow(e);
    }
  }

  @override
  Future<String> claimClient({
    required String watcherToken,
    required String code,
    required String displayName,
  }) async {
    try {
      final r = await _dio.post(
        '/v1/clients/claim',
        data: {
          'code': code,
          'display_name': displayName,
        },
        options: _auth(watcherToken),
      );
      return r.data['client_id'] as String;
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<InviteResult> createInviteCode({required String clientToken}) async {
    try {
      final r = await _dio.post(
        '/v1/invite-codes',
        data: const <String, dynamic>{},
        options: _auth(clientToken),
      );
      return InviteResult.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<InviteStatus> getInviteStatus({
    required String clientToken,
    required String inviteId,
  }) async {
    try {
      final r = await _dio.get(
        '/v1/invite-codes/$inviteId',
        options: _auth(clientToken),
      );
      return InviteStatus.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // 招待コード期限切れ（404）はポーリング側で再発行する。
      if (e.response?.statusCode == 404) {
        return const InviteStatus(joined: false);
      }
      _rethrow(e);
    }
  }

  @override
  Future<String> joinClient({
    required String watcherToken,
    required String code,
    required String displayName,
  }) async {
    try {
      final r = await _dio.post(
        '/v1/clients/join',
        data: {
          'code': code,
          'display_name': displayName,
        },
        options: _auth(watcherToken),
      );
      return r.data['client_id'] as String;
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<List<String>> listMyWatchers({required String clientToken}) async {
    try {
      final r = await _dio.get(
        '/v1/clients/me/watchers',
        options: _auth(clientToken),
      );
      final list = (r.data as List<dynamic>);
      return list
          .map((e) => (e as Map<String, dynamic>)['display_name'] as String)
          .toList();
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> registerClientEmail({
    required String clientToken,
    required String email,
    required String password,
  }) async {
    try {
      await _dio.post(
        '/v1/clients/me/email',
        data: {'email': email, 'password': password},
        options: _auth(clientToken),
      );
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<ClientLoginResult> loginClient({
    required String email,
    required String password,
    required String platform,
    required String consentVersion,
    String? appVersion,
    String? fcmToken,
  }) async {
    try {
      final r = await _dio.post('/v1/clients/login', data: {
        'email': email,
        'password': password,
        'platform': platform,
        'consent_version': consentVersion,
        'app_version': ?appVersion,
        'fcm_token': ?fcmToken,
      });
      return ClientLoginResult.fromJson(r.data as Map<String, dynamic>);
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
  Future<String> sendSos({
    required String clientToken,
    double? lat,
    double? lng,
    required int batteryLevel,
    DateTime? capturedAt,
  }) async {
    try {
      final r = await _dio.post(
        '/v1/sos',
        data: {
          'lat': ?lat,
          'lng': ?lng,
          'battery_level': batteryLevel,
          'location_captured_at': ?capturedAt?.toUtc().toIso8601String(),
        },
        options: _auth(clientToken),
      );
      return r.data['incident_id'] as String;
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> confirmAlive({required String clientToken}) async {
    try {
      // 空ボディ POST は Content-Type: application/json + 空で 400 になるため
      // 空 JSON を明示送信する（pairing-codes と同じ Fastify 制約の予防対応）。
      await _dio.post(
        '/v1/confirm-alive',
        data: const <String, dynamic>{},
        options: _auth(clientToken),
      );
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> reportPermissionHealth({
    required String clientToken,
    required List<String> issues,
  }) async {
    try {
      await _dio.post(
        '/v1/permission-health',
        data: {'issues': issues},
        options: _auth(clientToken),
      );
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> updateDeviceFcmToken({
    required String clientToken,
    required String fcmToken,
  }) async {
    try {
      await _dio.put(
        '/v1/devices/me/fcm-token',
        data: {'fcm_token': fcmToken},
        options: _auth(clientToken),
      );
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> updateWatcherFcmToken({
    required String watcherToken,
    required String fcmToken,
  }) async {
    try {
      await _dio.put(
        '/v1/watchers/me/fcm-token',
        data: {'fcm_token': fcmToken},
        options: _auth(watcherToken),
      );
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<List<WatchedClient>> listClients({required String watcherToken}) async {
    try {
      final r = await _dio.get('/v1/clients', options: _auth(watcherToken));
      final list = (r.data as List<dynamic>);
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
      final list = (r.data as List<dynamic>);
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
  Future<SosIncident?> getActiveSos({
    required String watcherToken,
    required String clientId,
  }) async {
    try {
      final r = await _dio.get(
        '/v1/clients/$clientId/sos/active',
        options: _auth(watcherToken),
      );
      return SosIncident.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null; // アクティブSOSなし/権限なし
      _rethrow(e);
    }
  }

  @override
  Future<void> resolveSos({
    required String watcherToken,
    required String incidentId,
  }) async {
    try {
      // outcome は任意。空ボディでの 400 を避けるため空オブジェクトを送る。
      await _dio.post(
        '/v1/sos/$incidentId/resolve',
        data: const <String, dynamic>{},
        options: _auth(watcherToken),
      );
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<String> sendStampAsClient({
    required String clientToken,
    required String stamp,
  }) async {
    try {
      final r = await _dio.post(
        '/v1/stamps',
        data: {'stamp': stamp},
        options: _auth(clientToken),
      );
      return '${r.data['stamp_id']}';
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<String> sendStampAsWatcher({
    required String watcherToken,
    required String clientId,
    required String stamp,
  }) async {
    try {
      final r = await _dio.post(
        '/v1/clients/$clientId/stamps',
        data: {'stamp': stamp},
        options: _auth(watcherToken),
      );
      return '${r.data['stamp_id']}';
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<List<Stamp>> listMyStamps({
    required String clientToken,
    int limit = 50,
  }) async {
    try {
      final r = await _dio.get(
        '/v1/stamps/me',
        queryParameters: {'limit': limit},
        options: _auth(clientToken),
      );
      final list = (r.data as List<dynamic>);
      return list
          .map((e) => Stamp.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<List<Stamp>> listClientStamps({
    required String watcherToken,
    required String clientId,
    int limit = 50,
  }) async {
    try {
      final r = await _dio.get(
        '/v1/clients/$clientId/stamps',
        queryParameters: {'limit': limit},
        options: _auth(watcherToken),
      );
      final list = (r.data as List<dynamic>);
      return list
          .map((e) => Stamp.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _rethrow(e);
    }
  }
}
