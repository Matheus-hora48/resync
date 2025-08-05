import 'package:flutter/material.dart';
import 'package:resync/resync.dart';
import 'package:dio/dio.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configurar Resync
  await Resync.instance.initialize(
    defaultCacheTtl: Duration(minutes: 30),
    maxRetries: 3,
    retryConfiguration: RetryConfigurationPresets.socialMedia(),
  );
  
  runApp(SyncIndicatorDemoApp());
}

class SyncIndicatorDemoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resync Sync Indicator Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: SyncIndicatorDemoPage(),
    );
  }
}

class SyncIndicatorDemoPage extends StatefulWidget {
  @override
  _SyncIndicatorDemoPageState createState() => _SyncIndicatorDemoPageState();
}

class _SyncIndicatorDemoPageState extends State<SyncIndicatorDemoPage> {
  final Dio _dio = Dio();
  SyncIndicatorStyle _currentStyle = SyncIndicatorStyle.modern;
  SyncIndicatorPosition _currentPosition = SyncIndicatorPosition.topRight;
  bool _autoHide = true;
  bool _showPendingCount = true;
  bool _showConnectivity = true;

  @override
  void initState() {
    super.initState();
    _dio.interceptors.add(ResyncDioInterceptor(
      cacheManager: Resync.instance.cacheManager,
      syncManager: Resync.instance.syncManager,
      connectivityService: Resync.instance.connectivityService,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sync Indicator Demo'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Conteúdo principal
          SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                Text(
                  '🚀 Resync Sync Indicator',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Widget premium para indicadores de sincronização em produção',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                
                SizedBox(height: 32),
                
                // Configurações do Widget
                _buildConfigSection(),
                
                SizedBox(height: 32),
                
                // Botões de Teste
                _buildTestSection(),
                
                SizedBox(height: 32),
                
                // Estilos Disponíveis
                _buildStylesSection(),
                
                SizedBox(height: 32),
                
                // Informações
                _buildInfoSection(),
              ],
            ),
          ),
          
          // Sync Indicator - O widget em ação!
          ResyncSyncIndicator(
            position: _currentPosition,
            style: _currentStyle,
            autoHide: _autoHide,
            showPendingCount: _showPendingCount,
            showConnectivityStatus: _showConnectivity,
            showDetailsOnTap: true,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sync Indicator tocado!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConfigSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚙️ Configurações',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            // Estilo
            Text('Estilo Visual:', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: SyncIndicatorStyle.values.map((style) {
                return ChoiceChip(
                  label: Text(_getStyleName(style)),
                  selected: _currentStyle == style,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _currentStyle = style);
                    }
                  },
                );
              }).toList(),
            ),
            
            SizedBox(height: 16),
            
            // Posição
            Text('Posição na Tela:', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: SyncIndicatorPosition.values.map((position) {
                return ChoiceChip(
                  label: Text(_getPositionName(position)),
                  selected: _currentPosition == position,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _currentPosition = position);
                    }
                  },
                );
              }).toList(),
            ),
            
            SizedBox(height: 16),
            
            // Switches
            SwitchListTile(
              title: Text('Auto-hide'),
              subtitle: Text('Esconder quando não há atividade'),
              value: _autoHide,
              onChanged: (value) => setState(() => _autoHide = value),
            ),
            SwitchListTile(
              title: Text('Mostrar contador'),
              subtitle: Text('Número de itens pendentes'),
              value: _showPendingCount,
              onChanged: (value) => setState(() => _showPendingCount = value),
            ),
            SwitchListTile(
              title: Text('Mostrar conectividade'),
              subtitle: Text('Ícone de status da conexão'),
              value: _showConnectivity,
              onChanged: (value) => setState(() => _showConnectivity = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🧪 Testes de Funcionalidade',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testCacheRequest,
                    icon: Icon(Icons.cached),
                    label: Text('Testar Cache'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testOfflineRequest,
                    icon: Icon(Icons.sync_problem),
                    label: Text('Testar Offline'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testUpload,
                    icon: Icon(Icons.cloud_upload),
                    label: Text('Testar Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testMultipleRequests,
                    icon: Icon(Icons.flash_on),
                    label: Text('Múltiplas Req.'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStylesSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎨 Estilos Disponíveis',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            _buildStylePreview('Minimal', SyncIndicatorStyle.minimal, 
              'Apenas um ponto colorido - discreto e simples'),
            _buildStylePreview('Modern', SyncIndicatorStyle.modern, 
              'Design moderno com bordas suaves e informações'),
            _buildStylePreview('Glass', SyncIndicatorStyle.glass, 
              'Efeito glass morphism - elegante e translúcido'),
            _buildStylePreview('Neon', SyncIndicatorStyle.neon, 
              'Estilo cyberpunk com efeitos neon brilhantes'),
          ],
        ),
      ),
    );
  }

  Widget _buildStylePreview(String name, SyncIndicatorStyle style, String description) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _currentStyle == style ? Colors.blue.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(8),
        border: _currentStyle == style ? Border.all(color: Colors.blue) : null,
      ),
      child: Row(
        children: [
          // Preview do estilo (simulado)
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _getStyleColor(style),
              borderRadius: BorderRadius.circular(style == SyncIndicatorStyle.minimal ? 12 : 8),
              boxShadow: style == SyncIndicatorStyle.neon ? [
                BoxShadow(color: _getStyleColor(style), blurRadius: 8)
              ] : null,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💡 Como Usar em Produção',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            Text(
              'Adicione ao seu app:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '''ResyncSyncIndicator(
  position: SyncIndicatorPosition.topRight,
  style: SyncIndicatorStyle.modern,
  autoHide: true,
  showDetailsOnTap: true,
)''',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            Text('✨ Funcionalidades:', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            ...[
              '• Indicador visual em tempo real',
              '• 4 estilos diferentes (minimal, modern, glass, neon)',
              '• 6 posições na tela',
              '• Auto-hide quando não há atividade',
              '• Modal com detalhes ao tocar',
              '• Animações suaves e profissionais',
              '• Otimizado para produção',
            ].map((item) => Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Text(item, style: TextStyle(fontSize: 14)),
            )),
          ],
        ),
      ),
    );
  }

  String _getStyleName(SyncIndicatorStyle style) {
    switch (style) {
      case SyncIndicatorStyle.minimal: return 'Minimal';
      case SyncIndicatorStyle.modern: return 'Modern';
      case SyncIndicatorStyle.glass: return 'Glass';
      case SyncIndicatorStyle.neon: return 'Neon';
    }
  }

  String _getPositionName(SyncIndicatorPosition position) {
    switch (position) {
      case SyncIndicatorPosition.topLeft: return 'Top Left';
      case SyncIndicatorPosition.topRight: return 'Top Right';
      case SyncIndicatorPosition.topCenter: return 'Top Center';
      case SyncIndicatorPosition.bottomLeft: return 'Bottom Left';
      case SyncIndicatorPosition.bottomRight: return 'Bottom Right';
      case SyncIndicatorPosition.bottomCenter: return 'Bottom Center';
    }
  }

  Color _getStyleColor(SyncIndicatorStyle style) {
    switch (style) {
      case SyncIndicatorStyle.minimal: return Colors.green;
      case SyncIndicatorStyle.modern: return Colors.blue;
      case SyncIndicatorStyle.glass: return Colors.cyan;
      case SyncIndicatorStyle.neon: return Colors.pink;
    }
  }

  Future<void> _testCacheRequest() async {
    try {
      await _dio.get('https://jsonplaceholder.typicode.com/posts/1');
      _showSnackbar('Requisição de cache enviada!', Colors.green);
    } catch (e) {
      _showSnackbar('Erro: $e', Colors.red);
    }
  }

  Future<void> _testOfflineRequest() async {
    try {
      await _dio.post(
        'https://httpbin.org/post',
        data: {'test': 'offline_sync', 'timestamp': DateTime.now().toIso8601String()},
      );
      _showSnackbar('Requisição offline enviada!', Colors.orange);
    } catch (e) {
      _showSnackbar('Requisição enfileirada para sync offline!', Colors.orange);
    }
  }

  Future<void> _testUpload() async {
    try {
      await Resync.instance.uploadManager.queueUpload(
        url: 'https://httpbin.org/post',
        filePath: '/tmp/test_file.txt',
        fileName: 'test.txt',
        formData: {'type': 'test'},
      );
      _showSnackbar('Upload enfileirado!', Colors.blue);
    } catch (e) {
      _showSnackbar('Erro no upload: $e', Colors.red);
    }
  }

  Future<void> _testMultipleRequests() async {
    for (int i = 0; i < 5; i++) {
      try {
        await _dio.post(
          'https://httpbin.org/post',
          data: {'batch': i, 'timestamp': DateTime.now().toIso8601String()},
        );
        await Future.delayed(Duration(milliseconds: 200));
      } catch (e) {
        // Requests will be queued
      }
    }
    _showSnackbar('5 requisições enviadas!', Colors.purple);
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
