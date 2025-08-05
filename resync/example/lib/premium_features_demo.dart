import 'package:flutter/material.dart';
import 'package:resync/resync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Resync
  await Resync.instance.initialize(
    defaultCacheTtl: Duration(minutes: 30),
    maxRetries: 5,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resync Premium Features Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ResyncDemoScreen(),
    );
  }
}

class ResyncDemoScreen extends StatefulWidget {
  const ResyncDemoScreen({super.key});

  @override
  ResyncDemoScreenState createState() => ResyncDemoScreenState();
}

class ResyncDemoScreenState extends State<ResyncDemoScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Resync Premium Features'),
        backgroundColor: Colors.blue[600],
      ),
      body: Column(
        children: [
          // Debug Panel - Diferencial Premium
          Container(
            margin: EdgeInsets.all(16),
            child: ResyncDebugPanel(
              height: 250,
              backgroundColor: Colors.grey[50],
            ),
          ),

          // Botões de demonstração
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Upload de arquivo
                  ElevatedButton.icon(
                    onPressed: _demonstrateFileUpload,
                    icon: Icon(Icons.upload_file),
                    label: Text('Demo Upload Offline'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Requests de teste
                  ElevatedButton.icon(
                    onPressed: _generateTestRequests,
                    icon: Icon(Icons.sync),
                    label: Text('Gerar Requests de Teste'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Cache teste
                  ElevatedButton.icon(
                    onPressed: _testCache,
                    icon: Icon(Icons.cached),
                    label: Text('Testar Cache'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),

                  SizedBox(height: 32),

                  // Upload Stats
                  FutureBuilder<Map<String, int>>(
                    future: Resync.instance.uploadManager.getUploadStats(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return Container();

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
                              SizedBox(height: 8),
                              ...stats.entries.map(
                                (entry) => Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(entry.key),
                                    Text(
                                      '${entry.value}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _demonstrateFileUpload() async {
    try {
      // Simula upload de arquivo
      final uploadId = await Resync.instance.uploadManager.queueUpload(
        url: 'https://httpbin.org/post',
        filePath: '/tmp/demo_file.txt', // Em app real, usar file picker
        fileName: 'demo_file.txt',
        formData: {
          'description': 'Arquivo de demonstração',
          'category': 'demo',
        },
        priority: 1,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload enfileirado: $uploadId'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {}); // Atualiza stats
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _generateTestRequests() async {
    // Simula algumas requisições que irão para a fila de sync
    final urls = [
      'https://httpbin.org/post',
      'https://httpbin.org/put',
      'https://httpbin.org/patch',
    ];

    for (int i = 0; i < 3; i++) {
      await Resync.instance.syncManager.addToQueue(
        SyncRequest(
          url: urls[i],
          method: HttpMethod.post,
          body: {'test_data': 'Demo request $i'},
          headers: {'Content-Type': 'application/json'},
        ),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('3 requests adicionados à fila de sync'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _testCache() async {
    // Testa o cache com alguns dados
    final cacheKey = 'demo_cache_${DateTime.now().millisecondsSinceEpoch}';

    await Resync.instance.cacheManager.put(cacheKey, {
      'demo_data': 'Cached at ${DateTime.now()}',
    }, ttl: Duration(minutes: 5));

    final cachedData = Resync.instance.cacheManager.get(cacheKey);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cache testado: ${cachedData != null ? 'OK' : 'ERRO'}'),
        backgroundColor: cachedData != null ? Colors.green : Colors.red,
      ),
    );
  }
}

/// Widget customizado para mostrar status de upload
class UploadProgressCard extends StatelessWidget {
  final UploadRequest upload;
  final VoidCallback? onCancel;

  const UploadProgressCard({super.key, required this.upload, this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    upload.fileName ?? 'Arquivo sem nome',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStatusChip(),
                if (onCancel != null && upload.status == UploadStatus.queued)
                  IconButton(
                    icon: Icon(Icons.cancel),
                    onPressed: onCancel,
                    color: Colors.red,
                  ),
              ],
            ),
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: upload.progress / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${upload.progress}%'),
                Text('${upload.attemptCount} tentativas'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String text;

    switch (upload.status) {
      case UploadStatus.queued:
        color = Colors.orange;
        text = 'Na fila';
        break;
      case UploadStatus.uploading:
        color = Colors.blue;
        text = 'Enviando';
        break;
      case UploadStatus.completed:
        color = Colors.green;
        text = 'Concluído';
        break;
      case UploadStatus.failed:
        color = Colors.red;
        text = 'Falhou';
        break;
      case UploadStatus.paused:
        color = Colors.grey;
        text = 'Pausado';
        break;
      case UploadStatus.cancelled:
        color = Colors.grey;
        text = 'Cancelado';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getProgressColor() {
    switch (upload.status) {
      case UploadStatus.uploading:
        return Colors.blue;
      case UploadStatus.completed:
        return Colors.green;
      case UploadStatus.failed:
        return Colors.red;
      case UploadStatus.paused:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
