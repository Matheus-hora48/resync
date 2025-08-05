import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../cache/cache_manager.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_request.dart';
import '../network/connectivity_service.dart';

/// Interceptor do Dio para cache e sincronização offline
class ResyncDioInterceptor extends Interceptor {
  final CacheManager _cacheManager;
  final SyncManager _syncManager;
  final ConnectivityService _connectivityService;
  final Duration? _defaultCacheTtl;
  final bool _cacheGetRequests;
  final bool _queueMutatingRequests;

  ResyncDioInterceptor({
    required CacheManager cacheManager,
    required SyncManager syncManager,
    required ConnectivityService connectivityService,
    Duration? defaultCacheTtl,
    bool cacheGetRequests = true,
    bool queueMutatingRequests = true,
  }) : _cacheManager = cacheManager,
       _syncManager = syncManager,
       _connectivityService = connectivityService,
       _defaultCacheTtl = defaultCacheTtl,
       _cacheGetRequests = cacheGetRequests,
       _queueMutatingRequests = queueMutatingRequests;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Para requisições GET, verifica cache se offline
    if (_shouldCheckCache(options)) {
      final cacheKey = _generateCacheKey(options);
      final cachedData = _cacheManager.get(cacheKey);

      if (cachedData != null && !_connectivityService.isConnected) {
        if (kDebugMode) {
          print('Retornando dados do cache (offline): ${options.uri}');
        }

        // Retorna resposta do cache
        final response = Response(
          requestOptions: options,
          data: cachedData['data'],
          statusCode: cachedData['statusCode'] ?? 200,
          statusMessage: cachedData['statusMessage'] ?? 'OK',
          headers: Headers.fromMap(
            Map<String, List<String>>.from(cachedData['headers'] ?? {}),
          ),
        );

        handler.resolve(response);
        return;
      }
    }

    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Armazena resposta GET em cache se habilitado
    if (_shouldCacheResponse(response)) {
      _cacheResponse(response);
    }

    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;

    // Se não há conexão, tenta cache para GET ou enfileira para outros métodos
    if (_isNetworkError(err) && !_connectivityService.isConnected) {
      // Para GET, tenta buscar no cache
      if (_shouldCheckCache(options)) {
        final cacheKey = _generateCacheKey(options);
        final cachedData = _cacheManager.get(cacheKey);

        if (cachedData != null) {
          if (kDebugMode) {
            print(
              'Retornando dados do cache após erro de rede: ${options.uri}',
            );
          }

          final response = Response(
            requestOptions: options,
            data: cachedData['data'],
            statusCode: cachedData['statusCode'] ?? 200,
            statusMessage: cachedData['statusMessage'] ?? 'OK (Cache)',
            headers: Headers.fromMap(
              Map<String, List<String>>.from(cachedData['headers'] ?? {}),
            ),
          );

          handler.resolve(response);
          return;
        }
      }

      // Para métodos que modificam dados, adiciona à fila de sincronização
      if (_shouldQueueRequest(options)) {
        _queueRequestForSync(options);

        // Retorna erro customizado indicando que foi enfileirado
        final queuedError = DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          message: 'Requisição enfileirada para sincronização offline',
        );

        handler.reject(queuedError);
        return;
      }
    }

    super.onError(err, handler);
  }

  /// Verifica se deve verificar cache para a requisição
  bool _shouldCheckCache(RequestOptions options) {
    return _cacheGetRequests &&
        options.method.toUpperCase() == 'GET' &&
        !_hasNoCache(options);
  }

  /// Verifica se deve fazer cache da resposta
  bool _shouldCacheResponse(Response response) {
    final options = response.requestOptions;
    return _cacheGetRequests &&
        options.method.toUpperCase() == 'GET' &&
        response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300 &&
        !_hasNoCache(options);
  }

  /// Verifica se deve enfileirar a requisição
  bool _shouldQueueRequest(RequestOptions options) {
    if (!_queueMutatingRequests) return false;

    final method = options.method.toUpperCase();
    return method == 'POST' ||
        method == 'PUT' ||
        method == 'PATCH' ||
        method == 'DELETE';
  }

  /// Verifica se o erro é de rede
  bool _isNetworkError(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout;
  }

  /// Verifica se a requisição tem diretiva no-cache
  bool _hasNoCache(RequestOptions options) {
    final cacheControl =
        options.headers['cache-control']?.toString().toLowerCase();
    return cacheControl?.contains('no-cache') == true ||
        cacheControl?.contains('no-store') == true;
  }

  /// Faz cache da resposta
  Future<void> _cacheResponse(Response response) async {
    try {
      final options = response.requestOptions;
      final cacheKey = _generateCacheKey(options);

      // Extrai TTL dos headers ou usa padrão
      Duration ttl = _defaultCacheTtl ?? const Duration(hours: 1);

      final cacheControl = response.headers.value('cache-control');
      if (cacheControl != null) {
        final maxAgeMatch = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
        if (maxAgeMatch != null) {
          final seconds = int.tryParse(maxAgeMatch.group(1)!);
          if (seconds != null) {
            ttl = Duration(seconds: seconds);
          }
        }
      }

      final cacheData = {
        'data': response.data,
        'statusCode': response.statusCode,
        'statusMessage': response.statusMessage,
        'headers': response.headers.map,
      };

      await _cacheManager.put(cacheKey, cacheData, ttl: ttl);

      if (kDebugMode) {
        print('Resposta armazenada em cache: ${options.uri} (TTL: $ttl)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao fazer cache da resposta: $e');
      }
    }
  }

  /// Adiciona requisição à fila de sincronização
  Future<void> _queueRequestForSync(RequestOptions options) async {
    try {
      final syncRequest = SyncRequest(
        url: options.uri.toString(),
        method: HttpMethod.fromString(options.method),
        headers: options.headers.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
        body: _serializeBody(options.data),
        queryParameters: options.queryParameters,
      );

      await _syncManager.addToQueue(syncRequest);

      if (kDebugMode) {
        print('Requisição adicionada à fila de sincronização: ${options.uri}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao enfileirar requisição: $e');
      }
    }
  }

  /// Serializa o body da requisição
  Map<String, dynamic>? _serializeBody(dynamic data) {
    if (data == null) return null;

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is String) {
      try {
        return json.decode(data) as Map<String, dynamic>;
      } catch (e) {
        // Se não é JSON válido, armazena como string
        return {'_raw_string': data};
      }
    }

    if (data is FormData) {
      // Para FormData, extrai campos
      final Map<String, dynamic> formFields = {};
      for (final field in data.fields) {
        formFields[field.key] = field.value;
      }

      // Para files, armazena apenas metadados (não o conteúdo)
      if (data.files.isNotEmpty) {
        formFields['_files'] =
            data.files
                .map(
                  (file) => {
                    'key': file.key,
                    'filename': file.value.filename,
                    'contentType': file.value.contentType?.toString(),
                  },
                )
                .toList();
      }

      return formFields;
    }

    // Para outros tipos, tenta converter para string
    try {
      return {'_serialized': data.toString()};
    } catch (e) {
      return null;
    }
  }

  /// Gera chave de cache para a requisição
  String _generateCacheKey(RequestOptions options) {
    return CacheManager.generateKey(
      options.uri.toString(),
      queryParameters: options.queryParameters,
    );
  }
}

/// Extensão para facilitar o uso do interceptor
extension ResyncDioExtension on Dio {
  /// Adiciona o interceptor Resync ao Dio
  void addResyncInterceptor({
    required CacheManager cacheManager,
    required SyncManager syncManager,
    required ConnectivityService connectivityService,
    Duration? defaultCacheTtl,
    bool cacheGetRequests = true,
    bool queueMutatingRequests = true,
  }) {
    interceptors.add(
      ResyncDioInterceptor(
        cacheManager: cacheManager,
        syncManager: syncManager,
        connectivityService: connectivityService,
        defaultCacheTtl: defaultCacheTtl,
        cacheGetRequests: cacheGetRequests,
        queueMutatingRequests: queueMutatingRequests,
      ),
    );
  }
}
