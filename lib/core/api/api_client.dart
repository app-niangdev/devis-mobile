import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config.dart';
import 'api_exception.dart';
import 'data_changes.dart';
import 'token_store.dart';

/// Codes qui ferment la session : l'utilisateur doit se reconnecter ou contacter l'administrateur.
const blockingCodes = {'SUBSCRIPTION_EXPIRED', 'TENANT_DISABLED', 'ACCOUNT_DISABLED'};

/// Client HTTP de l'API : jeton d'accès, renouvellement automatique sur 401,
/// et conversion des erreurs en [ApiException].
class ApiClient {
  ApiClient(this.tokens) {
    _dio = Dio(BaseOptions(
      baseUrl: apiUrl,
      headers: {'Accept': 'application/json'},
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 45),
    ));
  }

  final TokenStore tokens;
  late final Dio _dio;
  Completer<bool>? _refreshing;

  /// Prévient les écrans après chaque écriture réussie.
  final DataChanges changes = DataChanges();

  /// Session terminée (jeton révoqué, abonnement expiré, compte désactivé…).
  void Function(ApiException reason)? onSessionEnded;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: _clean(query), options: _auth()));

  Future<Map<String, dynamic>> post(String path, [Object? data]) =>
      _write(() => _dio.post(path, data: data, options: _auth()));

  Future<Map<String, dynamic>> put(String path, [Object? data]) =>
      _write(() => _dio.put(path, data: data, options: _auth()));

  Future<Map<String, dynamic>> delete(String path) =>
      _write(() => _dio.delete(path, options: _auth()));

  /// Appel public (connexion, OTP…) : pas de jeton, pas de renouvellement.
  Future<Map<String, dynamic>> postPublic(String path, Object? data) =>
      _send(() => _dio.post(path, data: data), retry: false);

  Future<Map<String, dynamic>> getPublic(String path) =>
      _send(() => _dio.get(path), retry: false);

  Future<Uint8List> getBytes(String path) async {
    try {
      final response = await _withRefresh(() => _dio.get<List<int>>(
            path,
            options: _auth().copyWith(responseType: ResponseType.bytes),
          ));
      return Uint8List.fromList(response.data ?? const []);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<Map<String, dynamic>> refreshSession() async {
    final response = await _dio.post(
      '/auth/refresh',
      options: Options(headers: {'Authorization': 'Bearer ${tokens.refreshToken}'}),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Options _auth() => Options(
        headers: {
          if (tokens.accessToken != null) 'Authorization': 'Bearer ${tokens.accessToken}',
        },
      );

  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    query?.removeWhere((_, value) => value == null || value == '');
    return query;
  }

  Future<Map<String, dynamic>> _write(Future<Response> Function() request) async {
    final body = await _send(request);
    changes.notify();
    return body;
  }

  Future<Map<String, dynamic>> _send(Future<Response> Function() request, {bool retry = true}) async {
    try {
      final response = retry ? await _withRefresh(request) : await request();
      final data = response.data;
      return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    } on DioException catch (e) {
      final error = _toApiException(e);
      if (retry && blockingCodes.contains(error.code)) {
        onSessionEnded?.call(error);
      }
      throw error;
    }
  }

  /// Rejoue la requête une fois après renouvellement du jeton d'accès expiré.
  Future<Response<T>> _withRefresh<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      if (e.response?.statusCode != 401 || tokens.refreshToken == null) {
        rethrow;
      }
      if (!await _refresh()) {
        onSessionEnded?.call(ApiException('Votre session a expiré. Veuillez vous reconnecter.', code: 'TOKEN_INVALID'));
        rethrow;
      }
      return request();
    }
  }

  /// Un seul renouvellement à la fois, partagé par les requêtes en attente.
  Future<bool> _refresh() async {
    if (_refreshing != null) {
      return _refreshing!.future;
    }
    final completer = _refreshing = Completer<bool>();
    try {
      final body = await refreshSession();
      final payload = body['payload'] as Map;
      await tokens.save(payload['access_token'] as String, payload['refresh_token'] as String);
      completer.complete(true);
    } catch (_) {
      completer.complete(false);
    } finally {
      _refreshing = null;
    }
    return completer.future;
  }

  ApiException _toApiException(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return ApiException(
        (data['message'] ?? 'Une erreur est survenue.').toString(),
        code: data['error_code'] as String?,
        status: e.response?.statusCode,
        errors: data['errors'] is Map ? Map<String, dynamic>.from(data['errors'] as Map) : null,
        payload: data['payload'],
      );
    }

    final offline = e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout;
    return ApiException(
      offline
          ? 'Connexion impossible. Vérifiez votre accès à Internet puis réessayez.'
          : 'Une erreur est survenue. Réessayez dans un instant.',
      code: offline ? 'NETWORK' : null,
      status: e.response?.statusCode,
    );
  }
}
