import 'package:flutter/material.dart';
import 'dart:async';
import '../resync.dart';
import '../sync/sync_request.dart';

/// Widget de debug que mostra estatísticas em tempo real do Resync
/// Útil para desenvolvedores acompanharem cache, sync queue e conectividade
class ResyncDebugPanel extends StatefulWidget {
  final bool showCacheStats;
  final bool showSyncQueue;
  final bool showConnectivity;
  final double? height;
  final Color? backgroundColor;

  const ResyncDebugPanel({
    super.key,
    this.showCacheStats = true,
    this.showSyncQueue = true,
    this.showConnectivity = true,
    this.height,
    this.backgroundColor,
  });

  @override
  State<ResyncDebugPanel> createState() => _ResyncDebugPanelState();
}

class _ResyncDebugPanelState extends State<ResyncDebugPanel> {
  late StreamSubscription _syncSubscription;
  late StreamSubscription _connectivitySubscription;
  late Timer _refreshTimer;

  List<SyncRequest> _syncQueue = [];
  bool _isConnected = false;
  Map<String, int> _cacheStats = {};
  String _lastSyncEvent = 'Nenhum evento ainda';

  @override
  void initState() {
    super.initState();
    _initializeStreams();
    _refreshTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      if (mounted) {
        _updateStats();
      }
    });
  }

  void _initializeStreams() async {
    final resync = Resync.instance;

    // Stream de eventos de sincronização
    _syncSubscription = resync.syncManager.eventStream.listen((event) {
      if (mounted) {
        setState(() {
          _lastSyncEvent =
              '${event.type.name}: ${event.message ?? 'Evento de sync'}';
          _updateSyncQueue();
        });
      }
    });

    // Stream de conectividade
    _connectivitySubscription = resync.connectivityService.connectionStream
        .listen((isConnected) {
          if (mounted) {
            setState(() {
              _isConnected = isConnected;
            });
          }
        });

    _updateStats();
  }

  void _updateStats() async {
    final resync = Resync.instance;

    if (mounted) {
      setState(() {
        _isConnected = resync.connectivityService.isConnected;
        _updateSyncQueue();
        _updateCacheStats();
      });
    }
  }

  void _updateSyncQueue() async {
    // Como não há método getPendingRequests, vamos simular com dados mock
    // Em implementação futura, o SyncManager deveria expor essa funcionalidade

    if (mounted) {
      setState(() {
        // Por enquanto, lista vazia - seria ideal ter acesso à fila real
        _syncQueue = [];
      });
    }
  }

  void _updateCacheStats() {
    // Simula estatísticas do cache
    // Em implementação real, CacheManager deveria expor essas métricas
    setState(() {
      _cacheStats = {
        'Total Items': 0, // Em implementação futura
        'Cache Hits': 0, // Em implementação futura
        'Cache Misses': 0, // Em implementação futura
      };
    });
  }

  @override
  void dispose() {
    _syncSubscription.cancel();
    _connectivitySubscription.cancel();
    _refreshTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height ?? 300,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.grey[100],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[600],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.developer_mode, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Resync Debug Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Spacer(),
                _buildConnectionIndicator(),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showConnectivity) _buildConnectivitySection(),
                  if (widget.showSyncQueue) _buildSyncQueueSection(),
                  if (widget.showCacheStats) _buildCacheStatsSection(),
                  _buildLastEventSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _isConnected ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isConnected ? Icons.wifi : Icons.wifi_off,
            color: Colors.white,
            size: 16,
          ),
          SizedBox(width: 4),
          Text(
            _isConnected ? 'Online' : 'Offline',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectivitySection() {
    return _buildSection(
      'Conectividade',
      Column(
        children: [
          _buildInfoRow('Status', _isConnected ? 'Conectado' : 'Desconectado'),
          _buildInfoRow(
            'Última verificação',
            DateTime.now().toString().substring(11, 19),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncQueueSection() {
    return _buildSection(
      'Fila de Sincronização',
      Column(
        children: [
          _buildInfoRow('Requests pendentes', '${_syncQueue.length}'),
          if (_syncQueue.isNotEmpty) ...[
            SizedBox(height: 8),
            ..._syncQueue.take(3).map((request) => _buildRequestCard(request)),
            if (_syncQueue.length > 3)
              Text(
                '... e mais ${_syncQueue.length - 3} requests',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCacheStatsSection() {
    return _buildSection(
      'Estatísticas do Cache',
      Column(
        children:
            _cacheStats.entries
                .map((entry) => _buildInfoRow(entry.key, '${entry.value}'))
                .toList(),
      ),
    );
  }

  Widget _buildLastEventSection() {
    return _buildSection(
      'Último Evento',
      Text(
        _lastSyncEvent,
        style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.blue[700],
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12)),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(SyncRequest request) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 2),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildMethodChip(request.method.name),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.url,
                  style: TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Tentativas: ${request.attemptCount}', // Usando o campo correto
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodChip(String method) {
    Color color;
    switch (method.toUpperCase()) {
      case 'GET':
        color = Colors.green;
        break;
      case 'POST':
        color = Colors.blue;
        break;
      case 'PUT':
        color = Colors.orange;
        break;
      case 'DELETE':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        method,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
