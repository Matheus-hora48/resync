import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'cache/cache_manager.dart';
import 'sync/sync_manager.dart';
import 'storage/hive_storage.dart';
import 'network/connectivity_service.dart';
import 'upload/upload_manager.dart';
import 'config/retry_configuration.dart';

/// Classe principal do Resync
/// Responsável por inicializar e coordenar todos os componentes
class Resync {
  static Resync? _instance;
  static Resync get instance => _instance ??= Resync._();

  late final CacheManager _cacheManager;
  late final SyncManager _syncManager;
  late final HiveStorage _storage;
  late final ConnectivityService _connectivityService;
  late final UploadManager _uploadManager;
  late final RetryConfiguration _retryConfiguration;

  bool _initialized = false;

  Resync._();

  /// Inicializa o Resync
  /// Deve ser chamado antes de usar qualquer funcionalidade
  Future<void> initialize({
    String? storagePath,
    Duration defaultCacheTtl = const Duration(hours: 1),
    int maxRetries = 3,
    Duration initialRetryDelay = const Duration(seconds: 1),
    Map<String, String> Function()? getAuthHeaders,
    RetryConfiguration? retryConfiguration,
  }) async {
    if (_initialized) return;

    // Inicializa o Hive
    await Hive.initFlutter(storagePath);

    // Inicializa os componentes
    _storage = HiveStorage();
    await _storage.initialize();

    _connectivityService = ConnectivityService();
    await _connectivityService.initialize();

    // Inicializa configuração de retry
    _retryConfiguration = retryConfiguration ?? RetryConfiguration();

    _cacheManager = CacheManager(
      storage: _storage,
      defaultTtl: defaultCacheTtl,
    );

    _syncManager = SyncManager(
      storage: _storage,
      connectivityService: _connectivityService,
      maxRetries: maxRetries,
      initialRetryDelay: initialRetryDelay,
      getAuthHeaders: getAuthHeaders,
    );

    _uploadManager = UploadManager(
      storage: _storage,
      connectivityService: _connectivityService,
      maxRetries: maxRetries,
      retryDelay: initialRetryDelay,
      getAuthHeaders: getAuthHeaders,
    );

    _initialized = true;

    if (kDebugMode) {
      print('Resync initialized successfully');
    }
  }

  /// Obtém o gerenciador de cache
  CacheManager get cacheManager {
    _ensureInitialized();
    return _cacheManager;
  }

  /// Obtém o gerenciador de sincronização
  SyncManager get syncManager {
    _ensureInitialized();
    return _syncManager;
  }

  /// Obtém o serviço de conectividade
  ConnectivityService get connectivityService {
    _ensureInitialized();
    return _connectivityService;
  }

  /// Obtém o gerenciador de uploads
  UploadManager get uploadManager {
    _ensureInitialized();
    return _uploadManager;
  }

  /// Obtém a configuração de retry
  RetryConfiguration get retryConfiguration {
    _ensureInitialized();
    return _retryConfiguration;
  }

  /// Limpa todos os dados armazenados
  Future<void> clearAll() async {
    _ensureInitialized();
    await _cacheManager.clearAll();
    await _syncManager.clearAll();
  }

  /// Finaliza o Resync e libera recursos
  Future<void> dispose() async {
    if (!_initialized) return;

    await _syncManager.dispose();
    await _connectivityService.dispose();
    _uploadManager.dispose();
    await Hive.close();

    _initialized = false;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'Resync não foi inicializado. Chame Resync.instance.initialize() primeiro.',
      );
    }
  }
}
