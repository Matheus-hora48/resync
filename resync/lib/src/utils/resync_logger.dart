import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Níveis de log disponíveis
enum LogLevel {
  debug(0, 'DEBUG'),
  info(1, 'INFO'),
  warning(2, 'WARN'),
  error(3, 'ERROR'),
  critical(4, 'CRITICAL');

  const LogLevel(this.priority, this.name);

  final int priority;
  final String name;
}

/// Entrada de log estruturada
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String component;
  final Map<String, dynamic>? metadata;
  final dynamic error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.level,
    required this.message,
    required this.component,
    DateTime? timestamp,
    this.metadata,
    this.error,
    this.stackTrace,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Converte para Map para serialização
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      'component': component,
      'metadata': metadata,
      'error': error?.toString(),
      'stackTrace': stackTrace?.toString(),
    };
  }

  /// Converte para JSON
  String toJson() => json.encode(toMap());

  /// Formata para log legível
  String toFormattedString() {
    final buffer = StringBuffer();
    buffer.write('${timestamp.toIso8601String()} ');
    buffer.write('[${level.name.padRight(8)}] ');
    buffer.write('[$component] ');
    buffer.write(message);

    if (metadata != null && metadata!.isNotEmpty) {
      buffer.write(' | Metadata: ${json.encode(metadata)}');
    }

    if (error != null) {
      buffer.write(' | Error: $error');
    }

    return buffer.toString();
  }

  @override
  String toString() => toFormattedString();
}

/// Sistema de logs estruturados para Resync
class ResyncLogger {
  static ResyncLogger? _instance;
  static ResyncLogger get instance => _instance ??= ResyncLogger._();

  final List<LogEntry> _logBuffer = [];
  final List<void Function(LogEntry)> _listeners = [];

  LogLevel _minimumLevel = LogLevel.info;
  int _maxBufferSize = 1000;
  bool _enableFileLogging = false;
  String? _logFilePath;
  File? _logFile;

  ResyncLogger._();

  /// Configura o logger
  void configure({
    LogLevel minimumLevel = LogLevel.info,
    int maxBufferSize = 1000,
    bool enableFileLogging = false,
    String? logFilePath,
  }) {
    _minimumLevel = minimumLevel;
    _maxBufferSize = maxBufferSize;
    _enableFileLogging = enableFileLogging;
    _logFilePath = logFilePath;

    if (_enableFileLogging && _logFilePath != null) {
      _logFile = File(_logFilePath!);
    }
  }

  /// Adiciona listener para logs
  void addListener(void Function(LogEntry) listener) {
    _listeners.add(listener);
  }

  /// Remove listener
  void removeListener(void Function(LogEntry) listener) {
    _listeners.remove(listener);
  }

  /// Log genérico
  void log(
    LogLevel level,
    String message, {
    String component = 'Resync',
    Map<String, dynamic>? metadata,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    if (level.priority < _minimumLevel.priority) {
      return; // Filtra logs abaixo do nível mínimo
    }

    final entry = LogEntry(
      level: level,
      message: message,
      component: component,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
    );

    _processLogEntry(entry);
  }

  /// Log de debug
  void debug(
    String message, {
    String component = 'Resync',
    Map<String, dynamic>? metadata,
  }) {
    log(LogLevel.debug, message, component: component, metadata: metadata);
  }

  /// Log de informação
  void info(
    String message, {
    String component = 'Resync',
    Map<String, dynamic>? metadata,
  }) {
    log(LogLevel.info, message, component: component, metadata: metadata);
  }

  /// Log de warning
  void warning(
    String message, {
    String component = 'Resync',
    Map<String, dynamic>? metadata,
    dynamic error,
  }) {
    log(
      LogLevel.warning,
      message,
      component: component,
      metadata: metadata,
      error: error,
    );
  }

  /// Log de erro
  void error(
    String message, {
    String component = 'Resync',
    Map<String, dynamic>? metadata,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    log(
      LogLevel.error,
      message,
      component: component,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log crítico
  void critical(
    String message, {
    String component = 'Resync',
    Map<String, dynamic>? metadata,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    log(
      LogLevel.critical,
      message,
      component: component,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Processa entrada de log
  void _processLogEntry(LogEntry entry) {
    // Adiciona ao buffer
    _logBuffer.add(entry);

    // Mantém tamanho do buffer
    if (_logBuffer.length > _maxBufferSize) {
      _logBuffer.removeAt(0);
    }

    // Console log em debug mode
    if (kDebugMode) {
      debugPrint(entry.toFormattedString());
    }

    // Escreve em arquivo se habilitado
    if (_enableFileLogging && _logFile != null) {
      _writeToFile(entry);
    }

    // Notifica listeners
    for (final listener in _listeners) {
      try {
        listener(entry);
      } catch (e) {
        // Ignora erros nos listeners para não causar loop
      }
    }
  }

  /// Escreve log em arquivo
  void _writeToFile(LogEntry entry) {
    try {
      _logFile?.writeAsStringSync('${entry.toJson()}\n', mode: FileMode.append);
    } catch (e) {
      // Ignora erros de escrita para não causar loop
    }
  }

  /// Obtém logs do buffer
  List<LogEntry> getLogs({
    LogLevel? minimumLevel,
    String? component,
    int? limit,
  }) {
    var logs =
        _logBuffer.where((entry) {
          if (minimumLevel != null &&
              entry.level.priority < minimumLevel.priority) {
            return false;
          }
          if (component != null && entry.component != component) {
            return false;
          }
          return true;
        }).toList();

    if (limit != null && logs.length > limit) {
      logs = logs.sublist(logs.length - limit);
    }

    return logs;
  }

  /// Limpa buffer de logs
  void clearLogs() {
    _logBuffer.clear();
  }

  /// Exporta logs para arquivo
  Future<void> exportLogs(String filePath, {LogLevel? minimumLevel}) async {
    try {
      final logs = getLogs(minimumLevel: minimumLevel);
      final file = File(filePath);

      final buffer = StringBuffer();
      for (final log in logs) {
        buffer.writeln(log.toJson());
      }

      await file.writeAsString(buffer.toString());

      info(
        'Logs exportados para: $filePath',
        component: 'Logger',
        metadata: {'logsCount': logs.length},
      );
    } catch (e, stackTrace) {
      error(
        'Falha ao exportar logs',
        component: 'Logger',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Estatísticas dos logs
  Map<String, int> getLogStats() {
    final stats = <String, int>{};

    for (final level in LogLevel.values) {
      stats[level.name] = 0;
    }

    for (final log in _logBuffer) {
      stats[log.level.name] = (stats[log.level.name] ?? 0) + 1;
    }

    stats['total'] = _logBuffer.length;

    return stats;
  }

  /// Configurações de logger pré-definidas
  static void configureForProduction() {
    instance.configure(
      minimumLevel: LogLevel.warning,
      maxBufferSize: 500,
      enableFileLogging: true,
      logFilePath: '/tmp/resync_production.log',
    );
  }

  static void configureForDevelopment() {
    instance.configure(
      minimumLevel: LogLevel.debug,
      maxBufferSize: 2000,
      enableFileLogging: true,
      logFilePath: '/tmp/resync_development.log',
    );
  }

  static void configureBasic() {
    instance.configure(
      minimumLevel: LogLevel.info,
      maxBufferSize: 1000,
      enableFileLogging: false,
    );
  }
}
