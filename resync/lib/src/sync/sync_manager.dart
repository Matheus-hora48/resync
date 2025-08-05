import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../storage/hive_storage.dart';
import '../network/connectivity_service.dart';
import '../utils/resync_logger.dart';
import 'sync_request.dart';
import 'retry_policy.dart';

/// Status do processo de sincronização
enum SyncStatus {
  idle, // Não há sincronização em andamento
  processing, // Processando fila de sincronização
  paused, // Pausado (sem conexão)
  error, // Erro durante sincronização
}

/// Evento de sincronização
class SyncEvent {
  final String requestId;
  final SyncEventType type;
  final DateTime timestamp;
  final String? message;
  final dynamic error;

  SyncEvent({
    required this.requestId,
    required this.type,
    DateTime? timestamp,
    this.message,
    this.error,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'SyncEvent(id: $requestId, type: $type, message: $message)';
  }
}

/// Tipos de eventos de sincronização
enum SyncEventType {
  queued, // Requisição adicionada à fila
  started, // Sincronização iniciada
  completed, // Sincronização completada com sucesso
  failed, // Sincronização falhou
  retrying, // Tentando novamente
  cancelled, // Sincronização cancelada
}

/// Gerenciador de sincronização de requisições
class SyncManager {
  final HiveStorage _storage;
  final ConnectivityService _connectivityService;
  final RetryPolicy _retryPolicy;
  final Map<String, String> Function()? _getAuthHeaders;
  final Dio _dio;

  final StreamController<SyncEvent> _eventController =
      StreamController<SyncEvent>.broadcast();
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _processingTimer;
  SyncStatus _currentStatus = SyncStatus.idle;
  bool _isProcessing = false;
  bool _disposed = false;

  /// Stream de eventos de sincronização
  Stream<SyncEvent> get eventStream => _eventController.stream;

  /// Stream de status de sincronização
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Status atual da sincronização
  SyncStatus get currentStatus => _currentStatus;

  SyncManager({
    required HiveStorage storage,
    required ConnectivityService connectivityService,
    int maxRetries = 3,
    Duration initialRetryDelay = const Duration(seconds: 1),
    Map<String, String> Function()? getAuthHeaders,
    Dio? dio,
  }) : _storage = storage,
       _connectivityService = connectivityService,
       _retryPolicy = HttpRetryPolicy(
         maxRetries: maxRetries,
         initialDelay: initialRetryDelay,
       ),
       _getAuthHeaders = getAuthHeaders,
       _dio = dio ?? Dio() {
    _initializeSync();
  }

  /// Inicializa o gerenciador de sincronização
  void _initializeSync() {
    // Escuta mudanças na conectividade
    _connectivitySubscription = _connectivityService.connectionStream.listen(
      _onConnectivityChanged,
      onError: (error) {
        if (kDebugMode) {
          print('Erro no stream de conectividade: $error');
        }
      },
    );

    // Inicia processamento se já estiver conectado
    if (_connectivityService.isConnected) {
      _startProcessing();
    }

    if (kDebugMode) {
      print('SyncManager inicializado');
    }
  }

  /// Adiciona requisição à fila de sincronização
  Future<void> addToQueue(SyncRequest request) async {
    if (_disposed) return;

    await _storage.addToSyncQueue(request.id, request.toMap());

    // Log da operação
    ResyncLogger.instance.info(
      'Requisição adicionada à fila de sincronização',
      component: 'SyncManager',
      metadata: {
        'requestId': request.id,
        'method': request.method.value,
        'url': request.url,
      },
    );

    _emitEvent(
      SyncEvent(
        requestId: request.id,
        type: SyncEventType.queued,
        message: '${request.method.value} ${request.url}',
      ),
    );

    if (kDebugMode) {
      print('Requisição adicionada à fila: ${request.id}');
    }

    // Tenta processar imediatamente se conectado
    if (_connectivityService.isConnected && !_isProcessing) {
      _startProcessing();
    }
  }

  /// Callback chamado quando a conectividade muda
  void _onConnectivityChanged(bool isConnected) {
    if (_disposed) return;

    if (isConnected) {
      if (kDebugMode) {
        print('Conexão restaurada - iniciando sincronização');
      }
      _startProcessing();
    } else {
      if (kDebugMode) {
        print('Conexão perdida - pausando sincronização');
      }
      _pauseProcessing();
    }
  }

  /// Inicia o processamento da fila
  void _startProcessing() {
    if (_disposed || _isProcessing) return;

    _isProcessing = true;
    _updateStatus(SyncStatus.processing);

    _processingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_connectivityService.isConnected) {
        _pauseProcessing();
        return;
      }

      _processQueue();
    });
  }

  /// Pausa o processamento da fila
  void _pauseProcessing() {
    if (_disposed) return;

    _processingTimer?.cancel();
    _processingTimer = null;
    _isProcessing = false;
    _updateStatus(SyncStatus.paused);
  }

  /// Processa itens da fila de sincronização
  Future<void> _processQueue() async {
    if (_disposed || !_connectivityService.isConnected) return;

    final queueItems = _storage.getAllSyncQueueItems();
    if (queueItems.isEmpty) {
      _updateStatus(SyncStatus.idle);
      _pauseProcessing();
      return;
    }

    // Ordena por prioridade e data de criação
    final sortedRequests =
        queueItems.entries
            .map((entry) => SyncRequest.fromMap(entry.value))
            .where((request) => request.status == SyncRequestStatus.pending)
            .toList()
          ..sort((a, b) {
            final priorityComparison = b.priority.compareTo(a.priority);
            return priorityComparison != 0
                ? priorityComparison
                : a.createdAt.compareTo(b.createdAt);
          });

    for (final request in sortedRequests) {
      if (_disposed || !_connectivityService.isConnected) break;

      if (request.canRetry(_retryPolicy.maxRetries)) {
        await _processRequest(request);
      } else if (request.status == SyncRequestStatus.pending) {
        // Marca como falha final se excedeu tentativas
        final failedRequest = request.markAsFailed(
          'Máximo de tentativas excedido',
        );
        await _updateRequestInStorage(failedRequest);

        _emitEvent(
          SyncEvent(
            requestId: request.id,
            type: SyncEventType.failed,
            message: 'Falha final após ${request.attemptCount} tentativas',
          ),
        );
      }
    }
  }

  /// Processa uma requisição específica
  Future<void> _processRequest(SyncRequest request) async {
    // Verifica se deve aguardar antes de tentar
    if (request.lastAttemptAt != null) {
      final delay = _retryPolicy.calculateDelay(request.attemptCount + 1);
      final nextAttemptTime = request.lastAttemptAt!.add(delay);

      if (DateTime.now().isBefore(nextAttemptTime)) {
        return; // Ainda não é hora de tentar novamente
      }
    }

    final updatedRequest = request.prepareForRetry(null);
    await _updateRequestInStorage(updatedRequest);

    _emitEvent(
      SyncEvent(
        requestId: request.id,
        type:
            request.attemptCount > 1
                ? SyncEventType.retrying
                : SyncEventType.started,
        message:
            'Tentativa ${updatedRequest.attemptCount} de ${_retryPolicy.maxRetries}',
      ),
    );

    try {
      await _executeRequest(updatedRequest);

      // Sucesso - remove da fila
      await _storage.removeFromSyncQueue(request.id);

      _emitEvent(
        SyncEvent(
          requestId: request.id,
          type: SyncEventType.completed,
          message: 'Sincronizado com sucesso',
        ),
      );

      if (kDebugMode) {
        print('Requisição sincronizada com sucesso: ${request.id}');
      }
    } catch (error) {
      final failedRequest = updatedRequest.copyWith(
        lastError: error.toString(),
        status:
            updatedRequest.canRetry(_retryPolicy.maxRetries)
                ? SyncRequestStatus.pending
                : SyncRequestStatus.failed,
      );

      await _updateRequestInStorage(failedRequest);

      if (!failedRequest.canRetry(_retryPolicy.maxRetries)) {
        _emitEvent(
          SyncEvent(
            requestId: request.id,
            type: SyncEventType.failed,
            message: 'Falha final: ${error.toString()}',
            error: error,
          ),
        );
      }

      if (kDebugMode) {
        print('Erro ao sincronizar requisição ${request.id}: $error');
      }
    }
  }

  /// Executa uma requisição HTTP
  Future<void> _executeRequest(SyncRequest request) async {
    // Prepara headers
    final headers = <String, String>{...request.headers};

    // Adiciona headers de autenticação se fornecido
    if (_getAuthHeaders != null) {
      final authHeaders = _getAuthHeaders();
      headers.addAll(authHeaders);
    }

    // Prepara opções da requisição
    final options = Options(method: request.method.value, headers: headers);

    // Executa a requisição
    await _dio.request(
      request.url,
      options: options,
      data: request.body,
      queryParameters: request.queryParameters,
    );
  }

  /// Atualiza requisição no armazenamento
  Future<void> _updateRequestInStorage(SyncRequest request) async {
    await _storage.addToSyncQueue(request.id, request.toMap());
  }

  /// Emite evento de sincronização
  void _emitEvent(SyncEvent event) {
    if (!_disposed) {
      _eventController.add(event);
    }
  }

  /// Atualiza status da sincronização
  void _updateStatus(SyncStatus status) {
    if (_currentStatus != status && !_disposed) {
      _currentStatus = status;
      _statusController.add(status);
    }
  }

  /// Obtém todas as requisições na fila
  List<SyncRequest> getQueuedRequests() {
    final queueItems = _storage.getAllSyncQueueItems();
    return queueItems.entries
        .map((entry) => SyncRequest.fromMap(entry.value))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Cancela uma requisição específica
  Future<void> cancelRequest(String requestId) async {
    final queueItem = _storage.getSyncQueueItem(requestId);
    if (queueItem != null) {
      final request = SyncRequest.fromMap(queueItem);
      request.markAsCancelled();

      await _storage.removeFromSyncQueue(requestId);

      _emitEvent(
        SyncEvent(
          requestId: requestId,
          type: SyncEventType.cancelled,
          message: 'Requisição cancelada',
        ),
      );

      if (kDebugMode) {
        print('Requisição cancelada: $requestId');
      }
    }
  }

  /// Limpa todas as requisições da fila
  Future<void> clearAll() async {
    await _storage.clearSyncQueue();

    if (kDebugMode) {
      print('Fila de sincronização limpa');
    }
  }

  /// Força o processamento da fila (útil para testes)
  Future<void> forceSync() async {
    if (_connectivityService.isConnected) {
      await _processQueue();
    }
  }

  /// Finaliza o gerenciador
  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;

    await _connectivitySubscription?.cancel();
    _processingTimer?.cancel();

    await _eventController.close();
    await _statusController.close();

    if (kDebugMode) {
      print('SyncManager finalizado');
    }
  }
}
