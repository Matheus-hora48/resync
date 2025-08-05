import 'package:flutter/material.dart';
import 'package:resync/resync.dart';
import 'package:dio/dio.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configurar Resync com configurações reais
  await Resync.instance.initialize(
    defaultCacheTtl: Duration(minutes: 15),
    maxRetries: 3,
    retryConfiguration: RetryConfigurationPresets.socialMedia(),
    getAuthHeaders: () => {
      'Authorization': 'Bearer fake_token_${DateTime.now().millisecondsSinceEpoch}',
      'User-Agent': 'ResyncTestApp/1.0',
    },
  );
  
  // Configurar logger para desenvolvimento
  ResyncLogger.configureForDevelopment();
  
  runApp(ResyncRealTestApp());
}

class ResyncRealTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resync Real Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: RealTestPage(),
    );
  }
}

class RealTestPage extends StatefulWidget {
  @override
  _RealTestPageState createState() => _RealTestPageState();
}

class _RealTestPageState extends State<RealTestPage> {
  final Dio _dio = Dio();
  final List<String> _testResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dio.interceptors.add(ResyncDioInterceptor(
      cacheManager: Resync.instance.cacheManager,
      syncManager: Resync.instance.syncManager,
      connectivityService: Resync.instance.connectivityService,
    ));
    _setupSyncListener();
  }

  void _setupSyncListener() {
    // Simular listener de sync (remover se não existir o stream)
    // Resync.instance.syncManager.syncStatusStream.listen((status) {
    //   if (mounted) {
    //     setState(() {
    //       _testResults.add('� Evento de sync detectado');
    //     });
    //   }
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Resync Real Test'),
        backgroundColor: Colors.blue[700],
      ),
      body: Column(
        children: [
          // Debug Panel
          Container(
            height: 250,
            padding: EdgeInsets.all(16),
            child: ResyncDebugPanel(
              backgroundColor: Colors.grey[50],
              showCacheStats: true,
              showSyncQueue: true,
              showConnectivity: true,
            ),
          ),
          
          // Botões de Teste
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Testes de API Real',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  
                  _buildTestButton(
                    'Teste GET (Cache)',
                    'Testa cache automático com API real',
                    Colors.green,
                    _testCacheWithRealAPI,
                  ),
                  
                  _buildTestButton(
                    'Teste POST (Offline Sync)',
                    'Testa sincronização offline',
                    Colors.blue,
                    _testOfflineSync,
                  ),
                  
                  _buildTestButton(
                    'Teste Upload',
                    'Testa upload de arquivo',
                    Colors.orange,
                    _testFileUpload,
                  ),
                  
                  _buildTestButton(
                    'Teste Retry Avançado',
                    'Testa configurações de retry',
                    Colors.purple,
                    _testAdvancedRetry,
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Resultados dos testes
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resultados dos Testes:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _testResults.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    _testResults[_testResults.length - 1 - index],
                                    style: TextStyle(fontSize: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _isLoading
          ? CircularProgressIndicator()
          : FloatingActionButton(
              onPressed: _clearResults,
              child: Icon(Icons.clear),
              tooltip: 'Limpar resultados',
            ),
    );
  }

  Widget _buildTestButton(String title, String subtitle, Color color, VoidCallback onPressed) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.all(16),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _clearResults() {
    setState(() {
      _testResults.clear();
    });
  }

  Future<void> _testCacheWithRealAPI() async {
    setState(() => _isLoading = true);
    
    try {
      _addResult('🚀 Iniciando teste de cache...');
      
      // Primeira requisição (deve ir para API)
      final response1 = await _dio.get('https://jsonplaceholder.typicode.com/posts/1');
      _addResult('📡 Primeira requisição - Status: ${response1.statusCode}');
      
      await Future.delayed(Duration(seconds: 1));
      
      // Segunda requisição (deve vir do cache)
      final response2 = await _dio.get('https://jsonplaceholder.typicode.com/posts/1');
      _addResult('💾 Segunda requisição (cache) - Status: ${response2.statusCode}');
      
      _addResult('✅ Teste de cache concluído');
      
    } catch (e) {
      _addResult('❌ Erro no teste de cache: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testOfflineSync() async {
    setState(() => _isLoading = true);
    
    try {
      _addResult('🚀 Iniciando teste de sync offline...');
      
      // Simular requisição que pode falhar offline
      await _dio.post(
        'https://jsonplaceholder.typicode.com/posts',
        data: {
          'title': 'Teste Resync',
          'body': 'Testando sincronização offline',
          'userId': 1,
        },
      );
      
      _addResult('📤 Requisição POST enviada');
      
    } catch (e) {
      _addResult('⚠️ Requisição falhou, será sincronizada: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testFileUpload() async {
    setState(() => _isLoading = true);
    
    try {
      _addResult('🚀 Iniciando teste de upload...');
      
      // Criar arquivo temporário para teste
      final tempFile = File('/tmp/test_upload.txt');
      await tempFile.writeAsString('Teste de upload do Resync - ${DateTime.now()}');
      
      final uploadId = await Resync.instance.uploadManager.queueUpload(
        url: 'https://httpbin.org/post',
        filePath: tempFile.path,
        fileName: 'test_upload.txt',
        formData: {'test': 'resync_upload'},
        priority: 1,
      );
      
      _addResult('📤 Upload enfileirado com ID: $uploadId');
      
    } catch (e) {
      _addResult('❌ Erro no teste de upload: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testAdvancedRetry() async {
    setState(() => _isLoading = true);
    
    try {
      _addResult('🚀 Iniciando teste de retry avançado...');
      
      // Tentar endpoint que vai falhar para testar retry
      await _dio.get('https://httpbin.org/status/500');
      
    } catch (e) {
      _addResult('⚠️ Endpoint falhou, testando retry: $e');
      
      // Log das configurações de retry
      ResyncLogger.instance.info(
        'Testando configurações de retry avançado',
        component: 'RealTest',
        metadata: {'endpoint': '/status/500', 'expected': 'retry'},
      );
      
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addResult(String result) {
    setState(() {
      _testResults.add('${DateTime.now().toString().substring(11, 19)} - $result');
    });
    
    // Log estruturado
    ResyncLogger.instance.info(
      result,
      component: 'RealTest',
      metadata: {'timestamp': DateTime.now().toIso8601String()},
    );
  }
}
