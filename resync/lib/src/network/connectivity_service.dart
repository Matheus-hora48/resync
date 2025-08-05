import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Serviço para detectar conectividade de rede
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final StreamController<bool> _connectionStreamController =
      StreamController<bool>.broadcast();

  bool _isConnected = false;
  bool _initialized = false;

  /// Stream que emite true quando conectado, false quando desconectado
  Stream<bool> get connectionStream => _connectionStreamController.stream;

  /// Status atual da conexão
  bool get isConnected => _isConnected;

  /// Inicializa o serviço de conectividade
  Future<void> initialize() async {
    if (_initialized) return;

    // Verifica o status inicial da conexão
    await _checkInitialConnection();

    // Escuta mudanças na conectividade
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        if (kDebugMode) {
          print('Erro no ConnectivityService: $error');
        }
      },
    );

    _initialized = true;

    if (kDebugMode) {
      print(
        'ConnectivityService inicializado. Status inicial: ${_isConnected ? "conectado" : "desconectado"}',
      );
    }
  }

  /// Verifica o status inicial da conexão
  Future<void> _checkInitialConnection() async {
    try {
      final List<ConnectivityResult> connectivityResult =
          await _connectivity.checkConnectivity();
      _updateConnectionStatus(connectivityResult);
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao verificar conectividade inicial: $e');
      }
      _isConnected = false;
    }
  }

  /// Callback chamado quando a conectividade muda
  void _onConnectivityChanged(List<ConnectivityResult> result) {
    _updateConnectionStatus(result);
  }

  /// Atualiza o status da conexão
  void _updateConnectionStatus(List<ConnectivityResult> connectivityResult) {
    final bool wasConnected = _isConnected;

    // Considera conectado se houver qualquer tipo de conexão (exceto none)
    _isConnected = connectivityResult.any(
      (result) => result != ConnectivityResult.none,
    );

    // Emite evento se o status mudou
    if (wasConnected != _isConnected) {
      _connectionStreamController.add(_isConnected);

      if (kDebugMode) {
        print(
          'Status de conectividade mudou: ${_isConnected ? "conectado" : "desconectado"}',
        );
      }
    }
  }

  /// Verifica manualmente a conectividade
  Future<bool> checkConnectivity() async {
    _ensureInitialized();

    try {
      final List<ConnectivityResult> connectivityResult =
          await _connectivity.checkConnectivity();
      _updateConnectionStatus(connectivityResult);
      return _isConnected;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao verificar conectividade: $e');
      }
      return false;
    }
  }

  /// Obtém informações detalhadas da conectividade
  Future<List<ConnectivityResult>> getConnectivityResult() async {
    _ensureInitialized();

    try {
      return await _connectivity.checkConnectivity();
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao obter resultado da conectividade: $e');
      }
      return [ConnectivityResult.none];
    }
  }

  /// Finaliza o serviço e libera recursos
  Future<void> dispose() async {
    if (!_initialized) return;

    await _connectivitySubscription?.cancel();
    await _connectionStreamController.close();

    _initialized = false;

    if (kDebugMode) {
      print('ConnectivityService finalizado');
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'ConnectivityService não foi inicializado. Chame initialize() primeiro.',
      );
    }
  }
}
