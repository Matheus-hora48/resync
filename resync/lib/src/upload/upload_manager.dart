import 'dart:io';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../storage/hive_storage.dart';
import '../network/connectivity_service.dart';
import '../utils/image_compressor.dart';

/// Status de um upload
enum UploadStatus {
  queued, // Na fila esperando upload
  uploading, // Fazendo upload
  completed, // Upload concluizado com sucesso
  failed, // Falhou após todas as tentativas
  paused, // Pausado (sem conexão)
  cancelled, // Cancelado pelo usuário
}

/// Representa um arquivo para upload offline
class UploadRequest {
  final String id;
  final String url;
  final String filePath;
  final String? fileName;
  final Map<String, String> headers;
  final Map<String, dynamic>? formData;
  final DateTime createdAt;
  final int priority;

  UploadStatus status;
  int progress; // 0-100
  int attemptCount;
  String? error;
  DateTime? lastAttemptAt;
  int bytesUploaded;
  int totalBytes;

  UploadRequest({
    String? id,
    required this.url,
    required this.filePath,
    this.fileName,
    this.headers = const {},
    this.formData,
    DateTime? createdAt,
    this.priority = 0,
    this.status = UploadStatus.queued,
    this.progress = 0,
    this.attemptCount = 0,
    this.error,
    this.lastAttemptAt,
    this.bytesUploaded = 0,
    this.totalBytes = 0,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  /// Converte para Map para persistência
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'filePath': filePath,
      'fileName': fileName,
      'headers': headers,
      'formData': formData,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'priority': priority,
      'status': status.name,
      'progress': progress,
      'attemptCount': attemptCount,
      'error': error,
      'lastAttemptAt': lastAttemptAt?.millisecondsSinceEpoch,
      'bytesUploaded': bytesUploaded,
      'totalBytes': totalBytes,
    };
  }

  /// Cria instância a partir de Map
  factory UploadRequest.fromMap(Map<String, dynamic> map) {
    return UploadRequest(
      id: map['id'],
      url: map['url'],
      filePath: map['filePath'],
      fileName: map['fileName'],
      headers: Map<String, String>.from(map['headers'] ?? {}),
      formData:
          map['formData'] != null
              ? Map<String, dynamic>.from(map['formData'])
              : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      priority: map['priority'] ?? 0,
      status: UploadStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => UploadStatus.queued,
      ),
      progress: map['progress'] ?? 0,
      attemptCount: map['attemptCount'] ?? 0,
      error: map['error'],
      lastAttemptAt:
          map['lastAttemptAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['lastAttemptAt'])
              : null,
      bytesUploaded: map['bytesUploaded'] ?? 0,
      totalBytes: map['totalBytes'] ?? 0,
    );
  }

  /// Calcula a porcentagem de progresso
  double get progressPercentage {
    if (totalBytes == 0) return 0.0;
    return (bytesUploaded / totalBytes) * 100;
  }

  /// Indica se pode fazer retry
  bool canRetry(int maxRetries) {
    return attemptCount < maxRetries && status == UploadStatus.failed;
  }

  /// Atualiza o status do upload
  void updateStatus(UploadStatus newStatus, {String? errorMessage}) {
    status = newStatus;
    if (errorMessage != null) {
      error = errorMessage;
    }
    if (newStatus == UploadStatus.uploading) {
      lastAttemptAt = DateTime.now();
      attemptCount++;
    }
  }

  @override
  String toString() {
    return 'UploadRequest(id: $id, fileName: $fileName, status: $status, progress: $progress%)';
  }
}

/// Evento de upload
class UploadEvent {
  final String uploadId;
  final UploadEventType type;
  final DateTime timestamp;
  final String? message;
  final int? progress;
  final dynamic error;

  UploadEvent({
    required this.uploadId,
    required this.type,
    DateTime? timestamp,
    this.message,
    this.progress,
    this.error,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'UploadEvent(id: $uploadId, type: $type, progress: $progress%)';
  }
}

/// Tipos de eventos de upload
enum UploadEventType {
  queued, // Upload adicionado à fila
  started, // Upload iniciado
  progress, // Progresso atualizado
  completed, // Upload concluído
  failed, // Upload falhou
  retrying, // Tentando novamente
  cancelled, // Upload cancelado
  paused, // Upload pausado (sem conexão)
  resumed, // Upload retomado (conexão restaurada)
}

/// Gerenciador de uploads offline
class UploadManager {
  static const String _uploadsBoxName = 'uploads';

  final HiveStorage _storage;
  final ConnectivityService _connectivityService;
  final Dio _dio;
  final int maxRetries;
  final Duration retryDelay;
  final Map<String, String> Function()? _getAuthHeaders;

  final Map<String, CancelToken> _activeCancellationTokens = {};
  bool _isProcessing = false;
  bool _disposed = false;

  UploadManager({
    required HiveStorage storage,
    required ConnectivityService connectivityService,
    Dio? dio,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 5),
    Map<String, String> Function()? getAuthHeaders,
  }) : _storage = storage,
       _connectivityService = connectivityService,
       _dio = dio ?? Dio(),
       _getAuthHeaders = getAuthHeaders {
    _initializeUploadManager();
  }

  void _initializeUploadManager() {
    // Processa uploads pendentes quando conecta
    _connectivityService.connectionStream.listen((isConnected) {
      if (isConnected && !_isProcessing) {
        _processUploadQueue();
      }
    });
  }

  /// Adiciona arquivo para upload offline
  Future<String> queueUpload({
    required String url,
    required String filePath,
    String? fileName,
    Map<String, String>? headers,
    Map<String, dynamic>? formData,
    int priority = 0,
    bool compressImages = true,
  }) async {
    File file = File(filePath);

    if (!await file.exists()) {
      throw ArgumentError('Arquivo não encontrado: $filePath');
    }

    // Comprime imagem se habilitado e for uma imagem
    if (compressImages && ImageCompressor.isImage(filePath)) {
      try {
        file = await ImageCompressor.compressImage(file);
        if (kDebugMode) {
          debugPrint('Imagem comprimida automaticamente: ${file.path}');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Falha na compressão, usando arquivo original: $e');
        }
        // Continua com arquivo original se compressão falhar
      }
    }

    final fileSize = await file.length();
    final upload = UploadRequest(
      url: url,
      filePath: file.path, // Usa o arquivo (possivelmente comprimido)
      fileName: fileName ?? file.path.split('/').last,
      headers: headers ?? {},
      formData: formData,
      priority: priority,
      totalBytes: fileSize,
    );

    // Salva na fila persistente
    await _storage.put(_uploadsBoxName, upload.id, upload.toMap());

    if (kDebugMode) {
      print('Upload enfileirado: ${upload.fileName} (${upload.id})');
    }

    // Tenta processar imediatamente se conectado
    if (_connectivityService.isConnected) {
      _processUploadQueue();
    }

    return upload.id;
  }

  /// Cancela um upload
  Future<bool> cancelUpload(String uploadId) async {
    // Cancela se estiver em andamento
    final cancelToken = _activeCancellationTokens[uploadId];
    if (cancelToken != null) {
      cancelToken.cancel('Upload cancelado pelo usuário');
      _activeCancellationTokens.remove(uploadId);
    }

    // Remove da fila
    final uploadData = await _storage.get(_uploadsBoxName, uploadId);
    if (uploadData != null) {
      final upload = UploadRequest.fromMap(uploadData);
      upload.updateStatus(UploadStatus.cancelled);
      await _storage.put(_uploadsBoxName, uploadId, upload.toMap());

      if (kDebugMode) {
        print('Upload cancelado: ${upload.fileName}');
      }
      return true;
    }

    return false;
  }

  /// Retorna todos os uploads pendentes
  Future<List<UploadRequest>> getPendingUploads() async {
    final allUploads = await _storage.getAll(_uploadsBoxName);
    return allUploads.values
        .map((data) => UploadRequest.fromMap(data))
        .where(
          (upload) =>
              upload.status != UploadStatus.completed &&
              upload.status != UploadStatus.cancelled,
        )
        .toList()
      ..sort(
        (a, b) => b.priority.compareTo(a.priority),
      ); // Prioridade maior primeiro
  }

  /// Processa a fila de uploads
  Future<void> _processUploadQueue() async {
    if (_isProcessing || !_connectivityService.isConnected || _disposed) {
      return;
    }

    _isProcessing = true;

    try {
      final pendingUploads = await getPendingUploads();

      if (pendingUploads.isEmpty) {
        _isProcessing = false;
        return;
      }

      if (kDebugMode) {
        print('Processando ${pendingUploads.length} uploads pendentes');
      }

      // Processa uploads um por vez (para não sobrecarregar)
      for (final upload in pendingUploads) {
        if (!_connectivityService.isConnected || _disposed) {
          break;
        }

        await _processUpload(upload);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao processar fila de uploads: $e');
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Processa um upload individual
  Future<void> _processUpload(UploadRequest upload) async {
    if (upload.status == UploadStatus.completed ||
        upload.status == UploadStatus.cancelled) {
      return;
    }

    try {
      upload.updateStatus(UploadStatus.uploading);
      await _storage.put(_uploadsBoxName, upload.id, upload.toMap());

      final cancelToken = CancelToken();
      _activeCancellationTokens[upload.id] = cancelToken;

      final file = File(upload.filePath);
      if (!await file.exists()) {
        throw FileSystemException('Arquivo não encontrado', upload.filePath);
      }

      // Prepara FormData
      final formData = FormData();

      // Adiciona arquivo
      final multipartFile = await MultipartFile.fromFile(
        upload.filePath,
        filename: upload.fileName,
      );
      formData.files.add(MapEntry('file', multipartFile));

      // Adiciona campos extras do form
      if (upload.formData != null) {
        upload.formData!.forEach((key, value) {
          formData.fields.add(MapEntry(key, value.toString()));
        });
      }

      // Headers com auth atualizado
      final headers = Map<String, String>.from(upload.headers);
      if (_getAuthHeaders != null) {
        headers.addAll(_getAuthHeaders());
      }

      // Faz o upload com tracking de progresso
      final response = await _dio.post(
        upload.url,
        data: formData,
        options: Options(headers: headers),
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          upload.bytesUploaded = sent;
          upload.totalBytes = total;
          upload.progress = ((sent / total) * 100).round();

          // Salva progresso periodicamente
          _storage.put(_uploadsBoxName, upload.id, upload.toMap());

          if (kDebugMode && sent % (total ~/ 10) == 0) {
            // Log a cada 10%
            debugPrint('Upload ${upload.fileName}: ${upload.progress}%');
          }
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        upload.updateStatus(UploadStatus.completed);
        upload.progress = 100;

        if (kDebugMode) {
          print('Upload concluído: ${upload.fileName}');
        }
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Status HTTP inválido: ${response.statusCode}',
        );
      }
    } catch (e) {
      upload.updateStatus(UploadStatus.failed, errorMessage: e.toString());

      if (kDebugMode) {
        print('Erro no upload ${upload.fileName}: $e');
      }

      // Retry se possível
      if (upload.canRetry(maxRetries)) {
        await Future.delayed(retryDelay);
        if (_connectivityService.isConnected && !_disposed) {
          return _processUpload(upload); // Retry recursivo
        }
      }
    } finally {
      _activeCancellationTokens.remove(upload.id);
      await _storage.put(_uploadsBoxName, upload.id, upload.toMap());
    }
  }

  /// Limpa uploads completados/cancelados
  Future<void> cleanupCompletedUploads() async {
    final allUploads = await _storage.getAll(_uploadsBoxName);

    for (final entry in allUploads.entries) {
      final upload = UploadRequest.fromMap(entry.value);

      if (upload.status == UploadStatus.completed ||
          upload.status == UploadStatus.cancelled) {
        await _storage.delete(_uploadsBoxName, entry.key);
      }
    }

    if (kDebugMode) {
      print('Uploads completados/cancelados foram limpos');
    }
  }

  /// Retorna estatísticas dos uploads
  Future<Map<String, int>> getUploadStats() async {
    final allUploads = await _storage.getAll(_uploadsBoxName);
    final uploads =
        allUploads.values.map((data) => UploadRequest.fromMap(data)).toList();

    return {
      'total': uploads.length,
      'queued': uploads.where((u) => u.status == UploadStatus.queued).length,
      'uploading':
          uploads.where((u) => u.status == UploadStatus.uploading).length,
      'completed':
          uploads.where((u) => u.status == UploadStatus.completed).length,
      'failed': uploads.where((u) => u.status == UploadStatus.failed).length,
      'cancelled':
          uploads.where((u) => u.status == UploadStatus.cancelled).length,
    };
  }

  /// Limpa recursos quando não precisar mais
  void dispose() {
    _disposed = true;

    // Cancela todos os uploads ativos
    for (final cancelToken in _activeCancellationTokens.values) {
      cancelToken.cancel('UploadManager disposed');
    }
    _activeCancellationTokens.clear();
  }
}
