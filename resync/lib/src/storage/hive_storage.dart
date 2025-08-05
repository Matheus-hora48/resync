import 'package:hive_flutter/hive_flutter.dart';

/// Gerenciador de armazenamento usando Hive
class HiveStorage {
  static const String _cacheBoxName = 'resync_cache';
  static const String _syncQueueBoxName = 'resync_sync_queue';
  static const String _metadataBoxName = 'resync_metadata';

  late Box<Map<dynamic, dynamic>> _cacheBox;
  late Box<Map<dynamic, dynamic>> _syncQueueBox;
  late Box<Map<dynamic, dynamic>> _metadataBox;

  // Cache para boxes adicionais
  final Map<String, Box<Map<dynamic, dynamic>>> _additionalBoxes = {};

  bool _initialized = false;

  /// Inicializa o armazenamento
  Future<void> initialize() async {
    if (_initialized) return;

    _cacheBox = await Hive.openBox<Map<dynamic, dynamic>>(_cacheBoxName);
    _syncQueueBox = await Hive.openBox<Map<dynamic, dynamic>>(
      _syncQueueBoxName,
    );
    _metadataBox = await Hive.openBox<Map<dynamic, dynamic>>(_metadataBoxName);

    _initialized = true;
  }

  /// Armazena dados no cache
  Future<void> putCache(String key, Map<String, dynamic> data) async {
    _ensureInitialized();
    await _cacheBox.put(key, data);
  }

  /// Recupera dados do cache
  Map<String, dynamic>? getCache(String key) {
    _ensureInitialized();
    final data = _cacheBox.get(key);
    return data?.cast<String, dynamic>();
  }

  /// Remove item do cache
  Future<void> deleteCache(String key) async {
    _ensureInitialized();
    await _cacheBox.delete(key);
  }

  /// Limpa todo o cache
  Future<void> clearCache() async {
    _ensureInitialized();
    await _cacheBox.clear();
  }

  /// Obtém todas as chaves do cache
  List<String> getCacheKeys() {
    _ensureInitialized();
    return _cacheBox.keys.cast<String>().toList();
  }

  /// Adiciona item à fila de sincronização
  Future<void> addToSyncQueue(String id, Map<String, dynamic> data) async {
    _ensureInitialized();
    await _syncQueueBox.put(id, data);
  }

  /// Remove item da fila de sincronização
  Future<void> removeFromSyncQueue(String id) async {
    _ensureInitialized();
    await _syncQueueBox.delete(id);
  }

  /// Obtém item da fila de sincronização
  Map<String, dynamic>? getSyncQueueItem(String id) {
    _ensureInitialized();
    final data = _syncQueueBox.get(id);
    return data?.cast<String, dynamic>();
  }

  /// Obtém todos os itens da fila de sincronização
  Map<String, Map<String, dynamic>> getAllSyncQueueItems() {
    _ensureInitialized();
    final Map<String, Map<String, dynamic>> result = {};

    for (final key in _syncQueueBox.keys) {
      final data = _syncQueueBox.get(key);
      if (data != null) {
        result[key.toString()] = data.cast<String, dynamic>();
      }
    }

    return result;
  }

  /// Limpa toda a fila de sincronização
  Future<void> clearSyncQueue() async {
    _ensureInitialized();
    await _syncQueueBox.clear();
  }

  /// Armazena metadados
  Future<void> putMetadata(String key, Map<String, dynamic> data) async {
    _ensureInitialized();
    await _metadataBox.put(key, data);
  }

  /// Recupera metadados
  Map<String, dynamic>? getMetadata(String key) {
    _ensureInitialized();
    final data = _metadataBox.get(key);
    return data?.cast<String, dynamic>();
  }

  /// Remove metadados
  Future<void> deleteMetadata(String key) async {
    _ensureInitialized();
    await _metadataBox.delete(key);
  }

  /// Fecha todas as caixas
  Future<void> close() async {
    if (!_initialized) return;

    await _cacheBox.close();
    await _syncQueueBox.close();
    await _metadataBox.close();

    // Fecha boxes adicionais
    for (final box in _additionalBoxes.values) {
      await box.close();
    }
    _additionalBoxes.clear();

    _initialized = false;
  }

  /// Métodos genéricos para boxes customizadas

  /// Obtém ou cria uma box customizada
  Future<Box<Map<dynamic, dynamic>>> _getOrCreateBox(String boxName) async {
    if (_additionalBoxes.containsKey(boxName)) {
      return _additionalBoxes[boxName]!;
    }

    final box = await Hive.openBox<Map<dynamic, dynamic>>(boxName);
    _additionalBoxes[boxName] = box;
    return box;
  }

  /// Armazena dados em uma box específica
  Future<void> put(
    String boxName,
    String key,
    Map<String, dynamic> data,
  ) async {
    _ensureInitialized();
    final box = await _getOrCreateBox(boxName);
    await box.put(key, data);
  }

  /// Recupera dados de uma box específica
  Future<Map<String, dynamic>?> get(String boxName, String key) async {
    _ensureInitialized();
    final box = await _getOrCreateBox(boxName);
    final data = box.get(key);
    return data?.cast<String, dynamic>();
  }

  /// Remove item de uma box específica
  Future<void> delete(String boxName, String key) async {
    _ensureInitialized();
    final box = await _getOrCreateBox(boxName);
    await box.delete(key);
  }

  /// Obtém todos os itens de uma box específica
  Future<Map<String, Map<String, dynamic>>> getAll(String boxName) async {
    _ensureInitialized();
    final box = await _getOrCreateBox(boxName);
    final Map<String, Map<String, dynamic>> result = {};

    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        result[key.toString()] = data.cast<String, dynamic>();
      }
    }

    return result;
  }

  /// Limpa uma box específica
  Future<void> clearBox(String boxName) async {
    _ensureInitialized();
    final box = await _getOrCreateBox(boxName);
    await box.clear();
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'HiveStorage não foi inicializado. Chame initialize() primeiro.',
      );
    }
  }
}
