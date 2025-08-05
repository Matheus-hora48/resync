import 'package:flutter/material.dart';
import 'package:resync/resync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configura logger para desenvolvimento
  ResyncLogger.configureForDevelopment();

  // Configuração avançada de retry para e-commerce
  final retryConfig = RetryConfigurationPresets.ecommerce();

  // Inicializa o Resync com configurações premium
  await Resync.instance.initialize(
    defaultCacheTtl: Duration(minutes: 30),
    maxRetries: 5,
    retryConfiguration: retryConfig,
    getAuthHeaders:
        () => {
          'Authorization': 'Bearer ${_getCurrentToken()}',
          'X-App-Version': '2.0.0',
        },
  );

  runApp(ResyncPremiumApp());
}

String _getCurrentToken() {
  // Simula obtenção de token atualizado
  return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
}

class ResyncPremiumApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resync Premium Features',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: PremiumFeaturesDemo(),
    );
  }
}

class PremiumFeaturesDemo extends StatefulWidget {
  @override
  _PremiumFeaturesDemoState createState() => _PremiumFeaturesDemoState();
}

class _PremiumFeaturesDemoState extends State<PremiumFeaturesDemo> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Resync Premium Demo'),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentPage = index),
        children: [
          _buildDebugPanelPage(),
          _buildUploadManagerPage(),
          _buildAdvancedRetryPage(),
          _buildLoggingPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentPage,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Debug Panel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud_upload),
            label: 'Upload Manager',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_applications),
            label: 'Advanced Retry',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Logging'),
        ],
      ),
    );
  }

  Widget _buildDebugPanelPage() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('🎛️ Debug Panel Premium'),
          Text(
            'Dashboard visual em tempo real para acompanhar todas as operações do Resync.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 16),

          // Debug Panel Widget
          ResyncDebugPanel(
            height: 300,
            backgroundColor: Colors.grey[50],
            showCacheStats: true,
            showSyncQueue: true,
            showConnectivity: true,
          ),

          SizedBox(height: 24),

          // Botões de teste
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _generateTestRequests,
                  icon: Icon(Icons.add_task),
                  label: Text('Gerar Requests'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testCache,
                  icon: Icon(Icons.cached),
                  label: Text('Testar Cache'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadManagerPage() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('📤 Upload Manager Premium'),
          Text(
            'Sistema robusto para upload de arquivos offline com compressão automática e retry inteligente.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 16),

          // Upload Statistics Card
          FutureBuilder<Map<String, int>>(
            future: Resync.instance.uploadManager.getUploadStats(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return CircularProgressIndicator();
              }

              final stats = snapshot.data!;
              return Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildStatRow('Total', stats['total'] ?? 0, Colors.blue),
                      _buildStatRow(
                        'Na fila',
                        stats['queued'] ?? 0,
                        Colors.orange,
                      ),
                      _buildStatRow(
                        'Enviando',
                        stats['uploading'] ?? 0,
                        Colors.blue,
                      ),
                      _buildStatRow(
                        'Concluídos',
                        stats['completed'] ?? 0,
                        Colors.green,
                      ),
                      _buildStatRow(
                        'Falharam',
                        stats['failed'] ?? 0,
                        Colors.red,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          SizedBox(height: 16),

          // Upload Actions
          _buildUploadActions(),

          SizedBox(height: 16),

          // Upload Features List
          _buildFeaturesList([
            '✅ Compressão automática de imagens',
            '✅ Sistema de prioridades',
            '✅ Progress tracking persistente',
            '✅ Retry automático com backoff',
            '✅ Cancelamento individual',
            '✅ Suporte a FormData e MultipartFile',
          ]),
        ],
      ),
    );
  }

  Widget _buildAdvancedRetryPage() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('⚙️ Advanced Retry Configuration'),
          Text(
            'Configurações granulares de retry por endpoint ou método HTTP.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 16),

          // Current Configuration Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configuração Atual: E-commerce',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  _buildConfigItem('/api/payment', 'Crítico (5 tentativas)'),
                  _buildConfigItem('/api/order', 'Crítico (5 tentativas)'),
                  _buildConfigItem('/api/analytics', 'Rápido (2 tentativas)'),
                  _buildConfigItem('POST requests', 'Crítico (5 tentativas)'),
                  _buildConfigItem('Default', 'Padrão (3 tentativas)'),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Configuration Presets
          _buildPresetsSection(),

          SizedBox(height: 16),

          // Test Buttons
          _buildRetryTestButtons(),
        ],
      ),
    );
  }

  Widget _buildLoggingPage() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('📝 Structured Logging System'),
          Text(
            'Sistema avançado de logs estruturados com níveis configuráveis.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 16),

          // Log Statistics
          _buildLogStatistics(),

          SizedBox(height: 16),

          // Log Actions
          _buildLogActions(),

          SizedBox(height: 16),

          // Recent Logs
          _buildRecentLogs(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$value',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _simulateImageUpload,
            icon: Icon(Icons.image),
            label: Text('Simular Upload de Imagem'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _simulateFileUpload,
            icon: Icon(Icons.file_upload),
            label: Text('Simular Upload de Arquivo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesList(List<String> features) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Funcionalidades Premium',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            ...features.map(
              (feature) => Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Text(feature, style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigItem(String endpoint, String config) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(endpoint, style: TextStyle(fontFamily: 'monospace')),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              config,
              style: TextStyle(fontSize: 12, color: Colors.blue[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configurações Pré-definidas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildPresetButton(
              'E-commerce',
              'Pagamentos críticos, analytics rápidos',
            ),
            _buildPresetButton(
              'Redes Sociais',
              'Posts importantes, métricas básicas',
            ),
            _buildPresetButton(
              'Enterprise',
              'Máxima confiabilidade, logs detalhados',
            ),
            _buildPresetButton('Básica', 'Configuração padrão simples'),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(String name, String description) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 4),
      child: OutlinedButton(
        onPressed: () => _applyRetryPreset(name),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
            Text(description, style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildRetryTestButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _testCriticalEndpoint,
            child: Text('Testar Endpoint Crítico'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _testAnalyticsEndpoint,
            child: Text('Testar Analytics'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ),
      ],
    );
  }

  Widget _buildLogStatistics() {
    final stats = ResyncLogger.instance.getLogStats();
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estatísticas de Logs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            ...stats.entries.map(
              (entry) => _buildStatRow(
                entry.key.toUpperCase(),
                entry.value,
                _getLogLevelColor(entry.key),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _generateTestLogs,
            icon: Icon(Icons.bug_report),
            label: Text('Gerar Logs Teste'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _exportLogs,
            icon: Icon(Icons.download),
            label: Text('Exportar Logs'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentLogs() {
    final recentLogs = ResyncLogger.instance.getLogs(limit: 5);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Logs Recentes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            if (recentLogs.isEmpty)
              Text(
                'Nenhum log encontrado',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...recentLogs.map((log) => _buildLogEntry(log)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 2),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getLogLevelColor(log.level.name).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getLogLevelColor(log.level.name),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  log.level.name,
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
              SizedBox(width: 8),
              Text(
                log.component,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Spacer(),
              Text(
                '${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(log.message, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Color _getLogLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        return Colors.grey;
      case 'info':
        return Colors.blue;
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      case 'critical':
        return Colors.red[900]!;
      default:
        return Colors.grey;
    }
  }

  // Event Handlers
  void _generateTestRequests() async {
    for (int i = 0; i < 3; i++) {
      await Resync.instance.syncManager.addToQueue(
        SyncRequest(
          url: 'https://httpbin.org/post',
          method: HttpMethod.post,
          body: {'test_data': 'Request $i'},
          headers: {'Content-Type': 'application/json'},
        ),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('3 requests de teste adicionados à fila')),
      );
    }
  }

  void _testCache() async {
    final cacheKey = 'demo_${DateTime.now().millisecondsSinceEpoch}';
    await Resync.instance.cacheManager.put(cacheKey, {
      'demo_data': 'Cached at ${DateTime.now()}',
    }, ttl: Duration(minutes: 5));

    final cachedData = Resync.instance.cacheManager.get(cacheKey);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cache testado: ${cachedData != null ? 'OK' : 'ERRO'}'),
          backgroundColor: cachedData != null ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _simulateImageUpload() async {
    try {
      final uploadId = await Resync.instance.uploadManager.queueUpload(
        url: 'https://httpbin.org/post',
        filePath: '/tmp/demo_image.jpg', // Arquivo simulado
        fileName: 'profile_picture.jpg',
        formData: {'type': 'profile', 'userId': '123'},
        priority: 2,
        compressImages: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload de imagem enfileirado: $uploadId'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() {}); // Atualiza estatísticas
  }

  void _simulateFileUpload() async {
    try {
      final uploadId = await Resync.instance.uploadManager.queueUpload(
        url: 'https://httpbin.org/post',
        filePath: '/tmp/document.pdf', // Arquivo simulado
        fileName: 'important_document.pdf',
        formData: {'category': 'documents'},
        priority: 1,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload de arquivo enfileirado: $uploadId'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() {}); // Atualiza estatísticas
  }

  void _applyRetryPreset(String presetName) {
    ResyncLogger.instance.info(
      'Aplicando preset de retry: $presetName',
      component: 'Demo',
      metadata: {'preset': presetName},
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Preset "$presetName" aplicado')));
  }

  void _testCriticalEndpoint() {
    ResyncLogger.instance.warning(
      'Testando endpoint crítico com retry avançado',
      component: 'RetryTest',
      metadata: {'endpoint': '/api/payment', 'retries': 5},
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Teste de endpoint crítico iniciado'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _testAnalyticsEndpoint() {
    ResyncLogger.instance.info(
      'Testando endpoint de analytics',
      component: 'RetryTest',
      metadata: {'endpoint': '/api/analytics', 'retries': 2},
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Teste de analytics iniciado'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _generateTestLogs() {
    ResyncLogger.instance.debug('Debug log de teste', component: 'Demo');
    ResyncLogger.instance.info('Info log de teste', component: 'Demo');
    ResyncLogger.instance.warning('Warning log de teste', component: 'Demo');
    ResyncLogger.instance.error(
      'Error log de teste',
      component: 'Demo',
      error: Exception('Erro simulado'),
    );

    setState(() {}); // Atualiza estatísticas

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Logs de teste gerados')));
  }

  void _exportLogs() async {
    try {
      await ResyncLogger.instance.exportLogs('/tmp/resync_logs.json');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logs exportados para /tmp/resync_logs.json'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Configurações do Demo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('Limpar Cache'),
                  leading: Icon(Icons.clear_all),
                  onTap: () {
                    // Implementar limpeza de cache
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: Text('Reset Upload Queue'),
                  leading: Icon(Icons.refresh),
                  onTap: () {
                    // Implementar reset da fila
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: Text('Clear Logs'),
                  leading: Icon(Icons.delete),
                  onTap: () {
                    ResyncLogger.instance.clearLogs();
                    Navigator.pop(context);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
    );
  }
}
