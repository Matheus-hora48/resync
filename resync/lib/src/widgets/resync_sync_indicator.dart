import 'dart:async';
import 'package:flutter/material.dart';
import '../resync.dart';

/// Widget premium para indicadores de sincronização em produção
/// Mostra status de sync, cache e conectividade de forma elegante
class ResyncSyncIndicator extends StatefulWidget {
  /// Posição do indicador na tela
  final SyncIndicatorPosition position;
  
  /// Estilo visual do indicador
  final SyncIndicatorStyle style;
  
  /// Se deve mostrar detalhes ao tocar
  final bool showDetailsOnTap;
  
  /// Callback quando o indicador é tocado
  final VoidCallback? onTap;
  
  /// Se deve auto-esconder quando tudo estiver sincronizado
  final bool autoHide;
  
  /// Duração da animação de entrada/saída
  final Duration animationDuration;
  
  /// Se deve mostrar contador de items pendentes
  final bool showPendingCount;
  
  /// Se deve mostrar indicador de conectividade
  final bool showConnectivityStatus;

  const ResyncSyncIndicator({
    Key? key,
    this.position = SyncIndicatorPosition.topRight,
    this.style = SyncIndicatorStyle.modern,
    this.showDetailsOnTap = true,
    this.onTap,
    this.autoHide = true,
    this.animationDuration = const Duration(milliseconds: 300),
    this.showPendingCount = true,
    this.showConnectivityStatus = true,
  }) : super(key: key);

  @override
  State<ResyncSyncIndicator> createState() => _ResyncSyncIndicatorState();
}

class _ResyncSyncIndicatorState extends State<ResyncSyncIndicator>
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  
  Timer? _updateTimer;
  SyncIndicatorData _data = SyncIndicatorData.empty();
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startPeriodicUpdates();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: _getSlideOffset(),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _slideController.forward();
  }

  Offset _getSlideOffset() {
    switch (widget.position) {
      case SyncIndicatorPosition.topLeft:
      case SyncIndicatorPosition.bottomLeft:
        return Offset(-1.0, 0.0);
      case SyncIndicatorPosition.topRight:
      case SyncIndicatorPosition.bottomRight:
        return Offset(1.0, 0.0);
      case SyncIndicatorPosition.topCenter:
        return Offset(0.0, -1.0);
      case SyncIndicatorPosition.bottomCenter:
        return Offset(0.0, 1.0);
    }
  }

  void _startPeriodicUpdates() {
    _updateData();
    _updateTimer = Timer.periodic(Duration(seconds: 1), (_) => _updateData());
  }

  Future<void> _updateData() async {
    try {
      // Simular dados por enquanto até implementar métodos reais
      final queueSize = 0; // Resync.instance.syncManager.getQueueSize();
      final isConnected = Resync.instance.connectivityService.isConnected;
      final uploadStats = await Resync.instance.uploadManager.getUploadStats();

      final newData = SyncIndicatorData(
        pendingSync: queueSize,
        isConnected: isConnected,
        cacheHitRate: 85.0, // Simular hit rate
        uploadsInProgress: uploadStats['uploading'] ?? 0,
        lastSyncTime: DateTime.now(),
      );

      if (mounted && newData != _data) {
        setState(() {
          _data = newData;
        });

        // Animar pulso quando há atividade
        if (newData.pendingSync > 0 || newData.uploadsInProgress > 0) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.reset();
        }

        // Auto-hide logic
        if (widget.autoHide) {
          final shouldShow = newData.pendingSync > 0 || 
                           newData.uploadsInProgress > 0 || 
                           !newData.isConnected;
          
          if (shouldShow != _isVisible) {
            setState(() => _isVisible = shouldShow);
            if (shouldShow) {
              _slideController.forward();
            } else {
              _slideController.reverse();
            }
          }
        }
      }
    } catch (e) {
      // Silently handle errors in production
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.autoHide && !_isVisible) {
      return SizedBox.shrink();
    }

    return Positioned(
      top: widget.position == SyncIndicatorPosition.topLeft || 
           widget.position == SyncIndicatorPosition.topRight || 
           widget.position == SyncIndicatorPosition.topCenter ? 16.0 : null,
      bottom: widget.position == SyncIndicatorPosition.bottomLeft || 
              widget.position == SyncIndicatorPosition.bottomRight || 
              widget.position == SyncIndicatorPosition.bottomCenter ? 16.0 : null,
      left: widget.position == SyncIndicatorPosition.topLeft || 
            widget.position == SyncIndicatorPosition.bottomLeft ? 16.0 : null,
      right: widget.position == SyncIndicatorPosition.topRight || 
             widget.position == SyncIndicatorPosition.bottomRight ? 16.0 : null,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onTap: () {
            if (widget.showDetailsOnTap) {
              _showDetailModal(context);
            }
            widget.onTap?.call();
          },
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: _buildIndicator(context),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator(BuildContext context) {
    switch (widget.style) {
      case SyncIndicatorStyle.minimal:
        return _buildMinimalIndicator(context);
      case SyncIndicatorStyle.modern:
        return _buildModernIndicator(context);
      case SyncIndicatorStyle.glass:
        return _buildGlassIndicator(context);
      case SyncIndicatorStyle.neon:
        return _buildNeonIndicator(context);
    }
  }

  Widget _buildMinimalIndicator(BuildContext context) {
    final color = _data.getStatusColor();
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildModernIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _data.getStatusColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status icon
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _data.getStatusColor(),
              shape: BoxShape.circle,
            ),
          ),
          
          if (widget.showPendingCount && _data.pendingSync > 0) ...[
            SizedBox(width: 6),
            Text(
              '${_data.pendingSync}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
          
          if (widget.showConnectivityStatus && !_data.isConnected) ...[
            SizedBox(width: 4),
            Icon(
              Icons.wifi_off,
              size: 12,
              color: Colors.orange,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlassIndicator(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated sync icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _data.pendingSync > 0 ? 1 : 0),
            duration: Duration(milliseconds: 500),
            builder: (context, value, child) {
              return Transform.rotate(
                angle: value * 2 * 3.14159,
                child: Icon(
                  Icons.sync,
                  size: 16,
                  color: _data.getStatusColor(),
                ),
              );
            },
          ),
          
          if (widget.showPendingCount && _data.pendingSync > 0) ...[
            SizedBox(width: 8),
            Text(
              '${_data.pendingSync}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNeonIndicator(BuildContext context) {
    final color = _data.getStatusColor();
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: color.withOpacity(0.8),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: color,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing dot
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color.withOpacity(value),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.8),
                      blurRadius: 3,
                    ),
                  ],
                ),
              );
            },
          ),
          
          if (widget.showPendingCount && _data.pendingSync > 0) ...[
            SizedBox(width: 8),
            Text(
              '${_data.pendingSync}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
                shadows: [
                  Shadow(
                    color: color.withOpacity(0.8),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDetailModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ResyncSyncDetailsModal(data: _data),
    );
  }
}

/// Modal com detalhes completos de sincronização
class ResyncSyncDetailsModal extends StatelessWidget {
  final SyncIndicatorData data;

  const ResyncSyncDetailsModal({
    Key? key,
    required this.data,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: data.getStatusColor().withOpacity(0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.sync,
                  color: data.getStatusColor(),
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Status de Sincronização',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Stats
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                _buildStatRow(
                  context,
                  'Pendentes',
                  '${data.pendingSync}',
                  Icons.pending_actions,
                  data.pendingSync > 0 ? Colors.orange : Colors.green,
                ),
                
                _buildStatRow(
                  context,
                  'Conectividade',
                  data.isConnected ? 'Online' : 'Offline',
                  data.isConnected ? Icons.wifi : Icons.wifi_off,
                  data.isConnected ? Colors.green : Colors.red,
                ),
                
                _buildStatRow(
                  context,
                  'Cache Hit Rate',
                  '${data.cacheHitRate.toStringAsFixed(1)}%',
                  Icons.cached,
                  data.cacheHitRate > 80 ? Colors.green : Colors.orange,
                ),
                
                _buildStatRow(
                  context,
                  'Uploads',
                  '${data.uploadsInProgress}',
                  Icons.cloud_upload,
                  data.uploadsInProgress > 0 ? Colors.blue : Colors.grey,
                ),
                
                SizedBox(height: 16),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Force sync
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.refresh),
                        label: Text('Forçar Sync'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: data.getStatusColor(),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // View logs
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.list_alt),
                        label: Text('Ver Logs'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Posições disponíveis para o indicador
enum SyncIndicatorPosition {
  topLeft,
  topRight,
  topCenter,
  bottomLeft,
  bottomRight,
  bottomCenter,
}

/// Estilos visuais disponíveis
enum SyncIndicatorStyle {
  minimal,    // Apenas um ponto colorido
  modern,     // Estilo moderno com bordas suaves
  glass,      // Efeito glass morphism
  neon,       // Estilo neon cyberpunk
}

/// Dados do indicador de sincronização
class SyncIndicatorData {
  final int pendingSync;
  final bool isConnected;
  final double cacheHitRate;
  final int uploadsInProgress;
  final DateTime lastSyncTime;

  const SyncIndicatorData({
    required this.pendingSync,
    required this.isConnected,
    required this.cacheHitRate,
    required this.uploadsInProgress,
    required this.lastSyncTime,
  });

  static SyncIndicatorData empty() {
    return SyncIndicatorData(
      pendingSync: 0,
      isConnected: true,
      cacheHitRate: 0.0,
      uploadsInProgress: 0,
      lastSyncTime: DateTime.now(),
    );
  }

  Color getStatusColor() {
    if (!isConnected) return Colors.red;
    if (pendingSync > 0 || uploadsInProgress > 0) return Colors.orange;
    return Colors.green;
  }

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is SyncIndicatorData &&
    runtimeType == other.runtimeType &&
    pendingSync == other.pendingSync &&
    isConnected == other.isConnected &&
    cacheHitRate == other.cacheHitRate &&
    uploadsInProgress == other.uploadsInProgress;

  @override
  int get hashCode =>
    pendingSync.hashCode ^
    isConnected.hashCode ^
    cacheHitRate.hashCode ^
    uploadsInProgress.hashCode;
}
