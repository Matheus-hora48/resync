import 'dart:math';

/// Estratégias de retry disponíveis
enum RetryStrategy {
  fixed, // Delay fixo entre tentativas
  exponential, // Backoff exponencial
  linear, // Incremento linear do delay
}

/// Política de retry para requisições falhadas
class RetryPolicy {
  final int maxRetries;
  final Duration initialDelay;
  final RetryStrategy strategy;
  final double multiplier;
  final Duration maxDelay;
  final bool addJitter;

  const RetryPolicy({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.strategy = RetryStrategy.exponential,
    this.multiplier = 2.0,
    this.maxDelay = const Duration(minutes: 5),
    this.addJitter = true,
  });

  /// Política padrão com backoff exponencial
  static const RetryPolicy defaultPolicy = RetryPolicy();

  /// Política agressiva para requisições críticas
  static const RetryPolicy aggressive = RetryPolicy(
    maxRetries: 5,
    initialDelay: Duration(milliseconds: 500),
    strategy: RetryStrategy.exponential,
    multiplier: 1.5,
    maxDelay: Duration(minutes: 2),
    addJitter: true,
  );

  /// Política conservativa para requisições não críticas
  static const RetryPolicy conservative = RetryPolicy(
    maxRetries: 2,
    initialDelay: Duration(seconds: 5),
    strategy: RetryStrategy.fixed,
    maxDelay: Duration(minutes: 10),
    addJitter: false,
  );

  /// Calcula o delay para a próxima tentativa
  Duration calculateDelay(int attemptNumber) {
    if (attemptNumber <= 0) return Duration.zero;

    Duration delay;

    switch (strategy) {
      case RetryStrategy.fixed:
        delay = initialDelay;
        break;

      case RetryStrategy.exponential:
        final factor = pow(multiplier, attemptNumber - 1).toDouble();
        delay = Duration(
          milliseconds: (initialDelay.inMilliseconds * factor).round(),
        );
        break;

      case RetryStrategy.linear:
        delay = Duration(
          milliseconds: initialDelay.inMilliseconds * attemptNumber,
        );
        break;
    }

    // Aplica o delay máximo
    if (delay > maxDelay) {
      delay = maxDelay;
    }

    // Adiciona jitter se habilitado
    if (addJitter) {
      delay = _addJitter(delay);
    }

    return delay;
  }

  /// Adiciona jitter ao delay para evitar thundering herd
  Duration _addJitter(Duration delay) {
    final random = Random();
    final jitterMs = (delay.inMilliseconds * 0.1).round(); // 10% de jitter
    final randomJitter = random.nextInt(jitterMs * 2) - jitterMs; // ±10%

    final newDelayMs = delay.inMilliseconds + randomJitter;
    return Duration(milliseconds: max(0, newDelayMs));
  }

  /// Verifica se deve tentar novamente baseado no número de tentativas
  bool shouldRetry(int attemptCount) {
    return attemptCount < maxRetries;
  }

  /// Verifica se deve tentar novamente baseado no erro
  bool shouldRetryForError(dynamic error) {
    // Por padrão, tenta novamente para qualquer erro
    // Subclasses podem override para lógica específica
    return true;
  }

  /// Cria uma cópia com parâmetros modificados
  RetryPolicy copyWith({
    int? maxRetries,
    Duration? initialDelay,
    RetryStrategy? strategy,
    double? multiplier,
    Duration? maxDelay,
    bool? addJitter,
  }) {
    return RetryPolicy(
      maxRetries: maxRetries ?? this.maxRetries,
      initialDelay: initialDelay ?? this.initialDelay,
      strategy: strategy ?? this.strategy,
      multiplier: multiplier ?? this.multiplier,
      maxDelay: maxDelay ?? this.maxDelay,
      addJitter: addJitter ?? this.addJitter,
    );
  }

  @override
  String toString() {
    return 'RetryPolicy(maxRetries: $maxRetries, initialDelay: $initialDelay, strategy: $strategy, multiplier: $multiplier, maxDelay: $maxDelay, addJitter: $addJitter)';
  }

  /// Converte para Map para serialização
  Map<String, dynamic> toMap() {
    return {
      'maxRetries': maxRetries,
      'initialDelay': initialDelay.inMilliseconds,
      'strategy': strategy.name,
      'multiplier': multiplier,
      'maxDelay': maxDelay.inMilliseconds,
      'addJitter': addJitter,
    };
  }

  /// Cria instância a partir de Map
  static RetryPolicy fromMap(Map<String, dynamic> map) {
    return RetryPolicy(
      maxRetries: map['maxRetries'] ?? 3,
      initialDelay: Duration(milliseconds: map['initialDelay'] ?? 1000),
      strategy: RetryStrategy.values.firstWhere(
        (e) => e.name == map['strategy'],
        orElse: () => RetryStrategy.exponential,
      ),
      multiplier: map['multiplier']?.toDouble() ?? 2.0,
      maxDelay: Duration(milliseconds: map['maxDelay'] ?? 300000),
      addJitter: map['addJitter'] ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RetryPolicy &&
        other.maxRetries == maxRetries &&
        other.initialDelay == initialDelay &&
        other.strategy == strategy &&
        other.multiplier == multiplier &&
        other.maxDelay == maxDelay &&
        other.addJitter == addJitter;
  }

  @override
  int get hashCode {
    return Object.hash(
      maxRetries,
      initialDelay,
      strategy,
      multiplier,
      maxDelay,
      addJitter,
    );
  }
}

/// Política de retry específica para HTTP
class HttpRetryPolicy extends RetryPolicy {
  final Set<int> retryableStatusCodes;
  final Set<int> nonRetryableStatusCodes;

  const HttpRetryPolicy({
    super.maxRetries,
    super.initialDelay,
    super.strategy,
    super.multiplier,
    super.maxDelay,
    super.addJitter,
    this.retryableStatusCodes = const {408, 429, 500, 502, 503, 504},
    this.nonRetryableStatusCodes = const {400, 401, 403, 404, 422},
  });

  /// Política HTTP padrão
  static const HttpRetryPolicy defaultHttp = HttpRetryPolicy();

  @override
  bool shouldRetryForError(dynamic error) {
    // Se for um erro HTTP, verifica o status code
    if (error is HttpException) {
      final statusCode = error.statusCode;

      // Não tenta novamente se estiver na lista de não retryable
      if (nonRetryableStatusCodes.contains(statusCode)) {
        return false;
      }

      // Tenta novamente se estiver na lista de retryable
      if (retryableStatusCodes.contains(statusCode)) {
        return true;
      }

      // Para outros códigos HTTP, não tenta novamente por padrão
      return false;
    }

    // Para outros tipos de erro, usa a lógica padrão
    return super.shouldRetryForError(error);
  }

  @override
  HttpRetryPolicy copyWith({
    int? maxRetries,
    Duration? initialDelay,
    RetryStrategy? strategy,
    double? multiplier,
    Duration? maxDelay,
    bool? addJitter,
    Set<int>? retryableStatusCodes,
    Set<int>? nonRetryableStatusCodes,
  }) {
    return HttpRetryPolicy(
      maxRetries: maxRetries ?? this.maxRetries,
      initialDelay: initialDelay ?? this.initialDelay,
      strategy: strategy ?? this.strategy,
      multiplier: multiplier ?? this.multiplier,
      maxDelay: maxDelay ?? this.maxDelay,
      addJitter: addJitter ?? this.addJitter,
      retryableStatusCodes: retryableStatusCodes ?? this.retryableStatusCodes,
      nonRetryableStatusCodes:
          nonRetryableStatusCodes ?? this.nonRetryableStatusCodes,
    );
  }
}

/// Exceção HTTP para uso com RetryPolicy
class HttpException implements Exception {
  final int statusCode;
  final String message;

  const HttpException(this.statusCode, this.message);

  @override
  String toString() => 'HttpException($statusCode): $message';
}
