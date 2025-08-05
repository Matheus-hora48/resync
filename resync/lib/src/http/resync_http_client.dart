import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../cache/cache_manager.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_request.dart';
import '../network/connectivity_service.dart';

/// Cliente HTTP que adiciona cache e sincronização offline
/// Wrapper para o package `http` padrão do Flutter
class ResyncHttpClient extends http.BaseClient {
  final http.Client _baseClient;
  final CacheManager _cacheManager;
  final SyncManager _syncManager;
  final ConnectivityService _connectivityService;
  final Duration? _defaultCacheTtl;
  final bool _cacheGetRequests;
  final bool _queueMutatingRequests;

  ResyncHttpClient({
    http.Client? baseClient,
    required CacheManager cacheManager,
    required SyncManager syncManager,
    required ConnectivityService connectivityService,
    Duration? defaultCacheTtl,
    bool cacheGetRequests = true,
    bool queueMutatingRequests = true,
  }) : _baseClient = baseClient ?? http.Client(),
       _cacheManager = cacheManager,
       _syncManager = syncManager,
       _connectivityService = connectivityService,
       _defaultCacheTtl = defaultCacheTtl,
       _cacheGetRequests = cacheGetRequests,
       _queueMutatingRequests = queueMutatingRequests;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Para requisições GET, verifica cache se offline ou se existe cache válido
    if (_shouldCheckCache(request)) {
      final cacheKey = _generateCacheKey(request);
      final cachedData = _cacheManager.get(cacheKey);

      if (cachedData != null && !_connectivityService.isConnected) {
        if (kDebugMode) {
          debugPrint('Retornando dados do cache (offline): ${request.url}');
        }

        // Retorna resposta do cache
        return _createResponseFromCache(request, cachedData);
      }
    }

    try {
      // Tenta executar a requisição
      final response = await _baseClient.send(request);

      // Se foi bem-sucedida, faz cache se for GET
      if (_shouldCacheResponse(request, response)) {
        await _cacheResponse(request, response);
      }

      return response;
    } catch (error) {
      // Se não há conexão, tenta cache para GET ou enfileira para outros métodos
      if (_isNetworkError(error) && !_connectivityService.isConnected) {
        // Para GET, tenta buscar no cache
        if (_shouldCheckCache(request)) {
          final cacheKey = _generateCacheKey(request);
          final cachedData = _cacheManager.get(cacheKey);

          if (cachedData != null) {
            if (kDebugMode) {
              debugPrint(
                'Retornando dados do cache após erro de rede: ${request.url}',
              );
            }

            return _createResponseFromCache(request, cachedData);
          }
        }

        // Para métodos que modificam dados, adiciona à fila de sincronização
        if (_shouldQueueRequest(request)) {
          await _queueRequestForSync(request);

          // Retorna erro customizado indicando que foi enfileirado
          throw ResyncOfflineException(
            'Requisição enfileirada para sincronização offline',
          );
        }
      }

      // Re-throw o erro original se não conseguiu lidar com ele
      rethrow;
    }
  }

  /// Verifica se deve verificar cache para a requisição
  bool _shouldCheckCache(http.BaseRequest request) {
    return _cacheGetRequests &&
        request.method.toUpperCase() == 'GET' &&
        !_hasNoCache(request);
  }

  /// Verifica se deve fazer cache da resposta
  bool _shouldCacheResponse(
    http.BaseRequest request,
    http.StreamedResponse response,
  ) {
    return _cacheGetRequests &&
        request.method.toUpperCase() == 'GET' &&
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        !_hasNoCache(request);
  }

  /// Verifica se deve enfileirar a requisição
  bool _shouldQueueRequest(http.BaseRequest request) {
    if (!_queueMutatingRequests) return false;

    final method = request.method.toUpperCase();
    return method == 'POST' ||
        method == 'PUT' ||
        method == 'PATCH' ||
        method == 'DELETE';
  }

  /// Verifica se o erro é de rede
  bool _isNetworkError(dynamic error) {
    // Para http package, geralmente são SocketException, TimeoutException, etc.
    return error.toString().toLowerCase().contains('socket') ||
        error.toString().toLowerCase().contains('network') ||
        error.toString().toLowerCase().contains('connection') ||
        error.toString().toLowerCase().contains('timeout');
  }

  /// Verifica se a requisição tem diretiva no-cache
  bool _hasNoCache(http.BaseRequest request) {
    final cacheControl = request.headers['cache-control']?.toLowerCase();
    return cacheControl?.contains('no-cache') == true ||
        cacheControl?.contains('no-store') == true;
  }

  /// Faz cache da resposta
  Future<void> _cacheResponse(
    http.BaseRequest request,
    http.StreamedResponse response,
  ) async {
    try {
      final cacheKey = _generateCacheKey(request);

      // Lê o corpo da resposta
      final bodyBytes = await response.stream.toBytes();
      final bodyString = utf8.decode(bodyBytes);

      // Tenta decodificar como JSON, senão mantém como string
      dynamic bodyData;
      try {
        bodyData = json.decode(bodyString);
      } catch (e) {
        bodyData = bodyString;
      }

      // Extrai TTL dos headers ou usa padrão
      Duration ttl = _defaultCacheTtl ?? const Duration(hours: 1);

      final cacheControl = response.headers['cache-control'];
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
        'data': bodyData,
        'statusCode': response.statusCode,
        'reasonPhrase': response.reasonPhrase,
        'headers': response.headers,
        'contentLength': response.contentLength,
        'bodyBytes': bodyBytes, // Armazena bytes originais
      };

      await _cacheManager.put(cacheKey, cacheData, ttl: ttl);

      if (kDebugMode) {
        debugPrint('Resposta armazenada em cache: ${request.url} (TTL: $ttl)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao fazer cache da resposta: $e');
      }
    }
  }

  /// Cria resposta do cache
  http.StreamedResponse _createResponseFromCache(
    http.BaseRequest request,
    Map<String, dynamic> cachedData,
  ) {
    final bodyBytes =
        cachedData['bodyBytes'] as List<int>? ??
        utf8.encode(cachedData['data']?.toString() ?? '');

    final response = http.StreamedResponse(
      Stream.fromIterable([bodyBytes]),
      cachedData['statusCode'] as int? ?? 200,
      contentLength: cachedData['contentLength'] as int?,
      request: request,
      headers: Map<String, String>.from(cachedData['headers'] ?? {}),
      reasonPhrase: cachedData['reasonPhrase'] as String?,
    );

    return response;
  }

  /// Adiciona requisição à fila de sincronização
  Future<void> _queueRequestForSync(http.BaseRequest request) async {
    try {
      // Lê o corpo da requisição se disponível
      Map<String, dynamic>? body;
      if (request is http.Request && request.body.isNotEmpty) {
        try {
          body = json.decode(request.body) as Map<String, dynamic>;
        } catch (e) {
          body = {'_raw_string': request.body};
        }
      }

      final syncRequest = SyncRequest(
        url: request.url.toString(),
        method: HttpMethod.fromString(request.method),
        headers: request.headers,
        body: body,
        queryParameters: request.url.queryParameters,
      );

      await _syncManager.addToQueue(syncRequest);

      if (kDebugMode) {
        debugPrint(
          'Requisição adicionada à fila de sincronização: ${request.url}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao enfileirar requisição: $e');
      }
    }
  }

  /// Gera chave de cache para a requisição
  String _generateCacheKey(http.BaseRequest request) {
    return CacheManager.generateKey(
      request.url.toString(),
      queryParameters: request.url.queryParameters,
    );
  }

  @override
  void close() {
    _baseClient.close();
    super.close();
  }

  // Métodos de conveniência para facilitar o uso

  /// Faz uma requisição GET
  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final request = http.Request('GET', url);
    if (headers != null) {
      request.headers.addAll(headers);
    }

    final streamedResponse = await send(request);
    return http.Response.fromStream(streamedResponse);
  }

  /// Faz uma requisição POST
  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final request = http.Request('POST', url);
    if (headers != null) {
      request.headers.addAll(headers);
    }
    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is Map) {
        request.body = json.encode(body);
        request.headers.putIfAbsent('content-type', () => 'application/json');
      }
    }

    final streamedResponse = await send(request);
    return http.Response.fromStream(streamedResponse);
  }

  /// Faz uma requisição PUT
  @override
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final request = http.Request('PUT', url);
    if (headers != null) {
      request.headers.addAll(headers);
    }
    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is Map) {
        request.body = json.encode(body);
        request.headers.putIfAbsent('content-type', () => 'application/json');
      }
    }

    final streamedResponse = await send(request);
    return http.Response.fromStream(streamedResponse);
  }

  /// Faz uma requisição PATCH
  @override
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final request = http.Request('PATCH', url);
    if (headers != null) {
      request.headers.addAll(headers);
    }
    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is Map) {
        request.body = json.encode(body);
        request.headers.putIfAbsent('content-type', () => 'application/json');
      }
    }

    final streamedResponse = await send(request);
    return http.Response.fromStream(streamedResponse);
  }

  /// Faz uma requisição DELETE
  @override
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final request = http.Request('DELETE', url);
    if (headers != null) {
      request.headers.addAll(headers);
    }
    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is Map) {
        request.body = json.encode(body);
        request.headers.putIfAbsent('content-type', () => 'application/json');
      }
    }

    final streamedResponse = await send(request);
    return http.Response.fromStream(streamedResponse);
  }
}

/// Exceção lançada quando uma requisição é enfileirada para sincronização offline
class ResyncOfflineException implements Exception {
  final String message;

  const ResyncOfflineException(this.message);

  @override
  String toString() => 'ResyncOfflineException: $message';
}

/// Extensão para facilitar o uso do client HTTP
extension ResyncHttpExtension on http.Client {
  /// Cria um ResyncHttpClient que wrappea este client
  ResyncHttpClient withResync({
    required CacheManager cacheManager,
    required SyncManager syncManager,
    required ConnectivityService connectivityService,
    Duration? defaultCacheTtl,
    bool cacheGetRequests = true,
    bool queueMutatingRequests = true,
  }) {
    return ResyncHttpClient(
      baseClient: this,
      cacheManager: cacheManager,
      syncManager: syncManager,
      connectivityService: connectivityService,
      defaultCacheTtl: defaultCacheTtl,
      cacheGetRequests: cacheGetRequests,
      queueMutatingRequests: queueMutatingRequests,
    );
  }
}
