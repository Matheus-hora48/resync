import 'package:flutter/foundation.dart';
import '../storage/hive_storage.dart';

/// Item de cache com metadados
class CacheItem {
  final String key;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final Duration ttl;

  CacheItem({
    required this.key,
    required this.data,
    required this.createdAt,
    required this.ttl,
  });

  /// Verifica se o item está expirado
  bool get isExpired => DateTime.now().isAfter(createdAt.add(ttl));

  /// Converte para Map para armazenamento
  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'data': data,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'ttlSeconds': ttl.inSeconds,
    };
  }

  /// Cria CacheItem a partir do Map
  factory CacheItem.fromMap(Map<String, dynamic> map) {
    return CacheItem(
      key: map['key'] as String,
      data: map['data'] as Map<String, dynamic>,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      ttl: Duration(seconds: map['ttlSeconds'] as int),
    );
  }
}

/// Gerenciador de cache
class CacheManager {
  final HiveStorage _storage;
  final Duration _defaultTtl;

  CacheManager({
    required HiveStorage storage,
    Duration defaultTtl = const Duration(hours: 1),
  }) : _storage = storage,
       _defaultTtl = defaultTtl;

  /// Armazena dados no cache
  Future<void> put(
    String key,
    Map<String, dynamic> data, {
    Duration? ttl,
  }) async {
    final cacheItem = CacheItem(
      key: key,
      data: data,
      createdAt: DateTime.now(),
      ttl: ttl ?? _defaultTtl,
    );

    await _storage.putCache(key, cacheItem.toMap());

    if (kDebugMode) {
      print('Cache armazenado: $key (TTL: ${cacheItem.ttl})');
    }
  }

  /// Recupera dados do cache
  Map<String, dynamic>? get(String key) {
    final cachedData = _storage.getCache(key);
    if (cachedData == null) return null;

    try {
      final cacheItem = CacheItem.fromMap(cachedData);

      // Verifica se o item está expirado
      if (cacheItem.isExpired) {
        // Remove o item expirado
        _storage.deleteCache(key);

        if (kDebugMode) {
          print('Cache expirado removido: $key');
        }

        return null;
      }

      if (kDebugMode) {
        print('Cache encontrado: $key');
      }

      return cacheItem.data;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao recuperar cache $key: $e');
      }

      // Remove item corrompido
      _storage.deleteCache(key);
      return null;
    }
  }

  /// Retorna todas as keys presentes no cache
  List<String> getAllKeys() {
    return _storage.getCacheKeys();
  }

  /// Verifica se existe cache válido para a chave
  bool hasValidCache(String key) {
    return get(key) != null;
  }

  /// Remove item específico do cache
  Future<void> delete(String key) async {
    await _storage.deleteCache(key);

    if (kDebugMode) {
      print('Cache removido: $key');
    }
  }

  /// Limpa todo o cache
  Future<void> clearAll() async {
    await _storage.clearCache();

    if (kDebugMode) {
      print('Todo o cache foi limpo');
    }
  }

  /// Remove itens expirados do cache
  Future<int> clearExpired() async {
    final keys = _storage.getCacheKeys();
    int removedCount = 0;

    for (final key in keys) {
      final cachedData = _storage.getCache(key);
      if (cachedData != null) {
        try {
          final cacheItem = CacheItem.fromMap(cachedData);
          if (cacheItem.isExpired) {
            await _storage.deleteCache(key);
            removedCount++;
          }
        } catch (e) {
          // Remove itens corrompidos
          await _storage.deleteCache(key);
          removedCount++;
        }
      }
    }

    if (kDebugMode && removedCount > 0) {
      debugPrint('$removedCount itens expirados removidos do cache');
    }

    return removedCount;
  }

  /// Obtém estatísticas do cache
  CacheStats getStats() {
    final keys = _storage.getCacheKeys();
    int validItems = 0;
    int expiredItems = 0;
    int corruptedItems = 0;

    for (final key in keys) {
      final cachedData = _storage.getCache(key);
      if (cachedData != null) {
        try {
          final cacheItem = CacheItem.fromMap(cachedData);
          if (cacheItem.isExpired) {
            expiredItems++;
          } else {
            validItems++;
          }
        } catch (e) {
          corruptedItems++;
        }
      }
    }

    return CacheStats(
      totalItems: keys.length,
      validItems: validItems,
      expiredItems: expiredItems,
      corruptedItems: corruptedItems,
    );
  }

  /// Gera chave de cache baseada na URL e parâmetros
  static String generateKey(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) {
    final uri = Uri.parse(url);
    final Map<String, dynamic> allParams =
        {}
          ..addAll(uri.queryParameters)
          ..addAll(queryParameters ?? {});

    // Ordena os parâmetros para gerar chave consistente
    final sortedParams = Map.fromEntries(
      allParams.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    final baseUrl = '${uri.scheme}://${uri.host}${uri.path}';
    final paramsString =
        sortedParams.isEmpty
            ? ''
            : '?${sortedParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';

    return '$baseUrl$paramsString';
  }
}

/// Estatísticas do cache
class CacheStats {
  final int totalItems;
  final int validItems;
  final int expiredItems;
  final int corruptedItems;

  CacheStats({
    required this.totalItems,
    required this.validItems,
    required this.expiredItems,
    required this.corruptedItems,
  });

  @override
  String toString() {
    return 'CacheStats(total: $totalItems, válidos: $validItems, expirados: $expiredItems, corrompidos: $corruptedItems)';
  }
}
