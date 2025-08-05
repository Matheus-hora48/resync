import 'package:uuid/uuid.dart';

/// Enum para tipos de requisição HTTP
enum HttpMethod {
  get,
  post,
  put,
  patch,
  delete;

  String get value {
    switch (this) {
      case HttpMethod.get:
        return 'GET';
      case HttpMethod.post:
        return 'POST';
      case HttpMethod.put:
        return 'PUT';
      case HttpMethod.patch:
        return 'PATCH';
      case HttpMethod.delete:
        return 'DELETE';
    }
  }

  static HttpMethod fromString(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return HttpMethod.get;
      case 'POST':
        return HttpMethod.post;
      case 'PUT':
        return HttpMethod.put;
      case 'PATCH':
        return HttpMethod.patch;
      case 'DELETE':
        return HttpMethod.delete;
      default:
        throw ArgumentError('Método HTTP não suportado: $method');
    }
  }
}

/// Status de uma requisição de sincronização
enum SyncRequestStatus {
  pending, // Aguardando sincronização
  processing, // Sendo processada
  completed, // Sincronizada com sucesso
  failed, // Falhou após todas as tentativas
  cancelled, // Cancelada
}

/// Representa uma requisição que precisa ser sincronizada
class SyncRequest {
  final String id;
  final String url;
  final HttpMethod method;
  final Map<String, String> headers;
  final Map<String, dynamic>? body;
  final Map<String, dynamic>? queryParameters;
  final DateTime createdAt;
  final int priority;

  DateTime? lastAttemptAt;
  int attemptCount;
  SyncRequestStatus status;
  String? lastError;

  SyncRequest({
    String? id,
    required this.url,
    required this.method,
    this.headers = const {},
    this.body,
    this.queryParameters,
    DateTime? createdAt,
    this.priority = 0,
    this.attemptCount = 0,
    this.status = SyncRequestStatus.pending,
    this.lastAttemptAt,
    this.lastError,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  /// Converte para Map para armazenamento
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'method': method.value,
      'headers': headers,
      'body': body,
      'queryParameters': queryParameters,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'priority': priority,
      'lastAttemptAt': lastAttemptAt?.millisecondsSinceEpoch,
      'attemptCount': attemptCount,
      'status': status.name,
      'lastError': lastError,
    };
  }

  /// Cria SyncRequest a partir do Map
  factory SyncRequest.fromMap(Map<String, dynamic> map) {
    return SyncRequest(
      id: map['id'] as String,
      url: map['url'] as String,
      method: HttpMethod.fromString(map['method'] as String),
      headers: Map<String, String>.from(map['headers'] ?? {}),
      body: map['body'] as Map<String, dynamic>?,
      queryParameters: map['queryParameters'] as Map<String, dynamic>?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      priority: map['priority'] as int? ?? 0,
      lastAttemptAt:
          map['lastAttemptAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['lastAttemptAt'] as int)
              : null,
      attemptCount: map['attemptCount'] as int? ?? 0,
      status: SyncRequestStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => SyncRequestStatus.pending,
      ),
      lastError: map['lastError'] as String?,
    );
  }

  /// Cria uma cópia com campos atualizados
  SyncRequest copyWith({
    String? id,
    String? url,
    HttpMethod? method,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    DateTime? createdAt,
    int? priority,
    DateTime? lastAttemptAt,
    int? attemptCount,
    SyncRequestStatus? status,
    String? lastError,
  }) {
    return SyncRequest(
      id: id ?? this.id,
      url: url ?? this.url,
      method: method ?? this.method,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      queryParameters: queryParameters ?? this.queryParameters,
      createdAt: createdAt ?? this.createdAt,
      priority: priority ?? this.priority,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      attemptCount: attemptCount ?? this.attemptCount,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
    );
  }

  /// Verifica se a requisição pode ser tentada novamente
  bool canRetry(int maxRetries) {
    return status == SyncRequestStatus.pending && attemptCount < maxRetries;
  }

  /// Atualiza a requisição para uma nova tentativa
  SyncRequest prepareForRetry(String? error) {
    return copyWith(
      lastAttemptAt: DateTime.now(),
      attemptCount: attemptCount + 1,
      status: SyncRequestStatus.processing,
      lastError: error,
    );
  }

  /// Marca a requisição como completada
  SyncRequest markAsCompleted() {
    return copyWith(status: SyncRequestStatus.completed, lastError: null);
  }

  /// Marca a requisição como falha final
  SyncRequest markAsFailed(String error) {
    return copyWith(status: SyncRequestStatus.failed, lastError: error);
  }

  /// Marca a requisição como cancelada
  SyncRequest markAsCancelled() {
    return copyWith(status: SyncRequestStatus.cancelled);
  }

  @override
  String toString() {
    return 'SyncRequest(id: $id, method: ${method.value}, url: $url, status: ${status.name}, attempts: $attemptCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncRequest && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
