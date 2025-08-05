import 'package:flutter_test/flutter_test.dart';
import 'package:resync/resync.dart';

void main() {
  group('Resync Components', () {
    test('deve criar requisição de sincronização', () {
      final request = SyncRequest(
        url: 'https://api.example.com/test',
        method: HttpMethod.post,
        body: {'test': 'data'},
      );

      expect(request.url, equals('https://api.example.com/test'));
      expect(request.method, equals(HttpMethod.post));
      expect(request.body, equals({'test': 'data'}));
      expect(request.status, equals(SyncRequestStatus.pending));
    });

    test('deve converter SyncRequest para Map e vice-versa', () {
      final originalRequest = SyncRequest(
        url: 'https://api.example.com/test',
        method: HttpMethod.put,
        headers: {'Content-Type': 'application/json'},
        body: {'test': 'data'},
        priority: 5,
      );

      final map = originalRequest.toMap();
      final reconstructedRequest = SyncRequest.fromMap(map);

      expect(reconstructedRequest.url, equals(originalRequest.url));
      expect(reconstructedRequest.method, equals(originalRequest.method));
      expect(reconstructedRequest.headers, equals(originalRequest.headers));
      expect(reconstructedRequest.body, equals(originalRequest.body));
      expect(reconstructedRequest.priority, equals(originalRequest.priority));
    });

    test('deve calcular delay corretamente para retry', () {
      const policy = RetryPolicy(
        initialDelay: Duration(seconds: 1),
        strategy: RetryStrategy.exponential,
        multiplier: 2.0,
        addJitter: false, // Remove jitter para testes determinísticos
      );

      final delay1 = policy.calculateDelay(1);
      final delay2 = policy.calculateDelay(2);
      final delay3 = policy.calculateDelay(3);

      expect(delay1.inSeconds, equals(1)); // 1 * 2^0 = 1
      expect(delay2.inSeconds, equals(2)); // 1 * 2^1 = 2  
      expect(delay3.inSeconds, equals(4)); // 1 * 2^2 = 4
    });

    test('deve gerar chave de cache consistente', () {
      const url = 'https://api.example.com/users';
      final params = {'page': '1', 'limit': '10'};

      final key1 = CacheManager.generateKey(url, queryParameters: params);
      final key2 = CacheManager.generateKey(url, queryParameters: params);

      expect(key1, equals(key2));
    });

    test('deve verificar se cache está expirado', () {
      final expiredItem = CacheItem(
        key: 'test',
        data: {'test': 'data'},
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ttl: const Duration(hours: 1),
      );

      final validItem = CacheItem(
        key: 'test',
        data: {'test': 'data'},
        createdAt: DateTime.now(),
        ttl: const Duration(hours: 1),
      );

      expect(expiredItem.isExpired, isTrue);
      expect(validItem.isExpired, isFalse);
    });

    test('deve criar diferentes tipos de HttpMethod', () {
      expect(HttpMethod.get.value, equals('GET'));
      expect(HttpMethod.post.value, equals('POST'));
      expect(HttpMethod.put.value, equals('PUT'));
      expect(HttpMethod.patch.value, equals('PATCH'));
      expect(HttpMethod.delete.value, equals('DELETE'));
    });

    test('deve criar HttpMethod a partir de string', () {
      expect(HttpMethod.fromString('GET'), equals(HttpMethod.get));
      expect(HttpMethod.fromString('post'), equals(HttpMethod.post));
      expect(HttpMethod.fromString('PUT'), equals(HttpMethod.put));
    });

    test('deve verificar se requisição pode fazer retry', () {
      final request = SyncRequest(
        url: 'https://api.example.com/test',
        method: HttpMethod.post,
        attemptCount: 2,
        status: SyncRequestStatus.pending,
      );

      expect(request.canRetry(3), isTrue);
      expect(request.canRetry(2), isFalse);
      expect(request.canRetry(1), isFalse);
    });

    test('deve atualizar status da requisição', () {
      final request = SyncRequest(
        url: 'https://api.example.com/test',
        method: HttpMethod.post,
      );

      final updatedRequest = request.markAsCompleted();
      expect(updatedRequest.status, equals(SyncRequestStatus.completed));

      final failedRequest = request.markAsFailed('Network error');
      expect(failedRequest.status, equals(SyncRequestStatus.failed));
      expect(failedRequest.lastError, equals('Network error'));
    });

    test('deve validar política de retry HTTP', () {
      const policy = HttpRetryPolicy();
      
      // Erros retryable
      expect(policy.shouldRetryForError(const HttpException(500, 'Server Error')), isTrue);
      expect(policy.shouldRetryForError(const HttpException(429, 'Too Many Requests')), isTrue);
      
      // Erros não-retryable
      expect(policy.shouldRetryForError(const HttpException(404, 'Not Found')), isFalse);
      expect(policy.shouldRetryForError(const HttpException(401, 'Unauthorized')), isFalse);
    });

    test('deve criar exceção offline personalizada', () {
      const exception = ResyncOfflineException('Test message');
      expect(exception.message, equals('Test message'));
      expect(exception.toString(), contains('ResyncOfflineException: Test message'));
    });

    test('deve validar diferentes estratégias de retry', () {
      // Estratégia fixa
      const fixedPolicy = RetryPolicy(
        strategy: RetryStrategy.fixed,
        initialDelay: Duration(seconds: 2),
        addJitter: false,
      );
      
      expect(fixedPolicy.calculateDelay(1).inSeconds, equals(2));
      expect(fixedPolicy.calculateDelay(3).inSeconds, equals(2));

      // Estratégia linear
      const linearPolicy = RetryPolicy(
        strategy: RetryStrategy.linear,
        initialDelay: Duration(seconds: 1),
        addJitter: false,
      );
      
      expect(linearPolicy.calculateDelay(1).inSeconds, equals(1));
      expect(linearPolicy.calculateDelay(2).inSeconds, equals(2));
      expect(linearPolicy.calculateDelay(3).inSeconds, equals(3));
    });
  });
}
