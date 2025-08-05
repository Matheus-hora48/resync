import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:resync/resync.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Resync
  await Resync.instance.initialize(
    defaultCacheTtl: const Duration(hours: 1),
    maxRetries: 3,
    initialRetryDelay: const Duration(seconds: 1),
    getAuthHeaders:
        () => {
          'Authorization': 'Bearer fake-token-123',
          'X-App-Version': '1.0.0',
        },
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resync Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Dio _dio;
  late StreamSubscription _syncSubscription;
  late StreamSubscription _connectivitySubscription;

  bool _isConnected = true;
  List<Map<String, dynamic>> _users = [];
  List<SyncRequest> _queuedRequests = [];
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeDio();
    _setupListeners();
    _loadUsers();
    _updateQueuedRequests();
  }

  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://jsonplaceholder.typicode.com',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );

    // Adiciona o interceptor Resync
    _dio.addResyncInterceptor(
      cacheManager: Resync.instance.cacheManager,
      syncManager: Resync.instance.syncManager,
      connectivityService: Resync.instance.connectivityService,
      defaultCacheTtl: const Duration(minutes: 30),
    );
  }

  void _setupListeners() {
    // Escuta eventos de sincronização
    _syncSubscription = Resync.instance.syncManager.eventStream.listen((event) {
      _updateQueuedRequests();

      switch (event.type) {
        case SyncEventType.completed:
          _showSnackBar('✅ Sincronizado: ${event.message}', Colors.green);
          _loadUsers(); // Recarrega dados após sincronização
          break;
        case SyncEventType.failed:
          _showSnackBar('❌ Erro: ${event.message}', Colors.red);
          break;
        case SyncEventType.queued:
          _showSnackBar('📋 Enfileirado: ${event.message}', Colors.orange);
          break;
        default:
          break;
      }
    });

    // Escuta mudanças de conectividade
    _connectivitySubscription = Resync
        .instance
        .connectivityService
        .connectionStream
        .listen((connected) {
          setState(() {
            _isConnected = connected;
          });

          if (connected) {
            _showSnackBar('🟢 Conectado', Colors.green);
          } else {
            _showSnackBar('🔴 Offline', Colors.red);
          }
        });

    // Status inicial da conectividade
    _isConnected = Resync.instance.connectivityService.isConnected;
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadUsers() async {
    try {
      final response = await _dio.get('/users');
      setState(() {
        _users = List<Map<String, dynamic>>.from(response.data);
      });
    } catch (e) {
      _showSnackBar('Erro ao carregar usuários: $e', Colors.red);
    }
  }

  Future<void> _addUser() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Por favor, digite um nome', Colors.orange);
      return;
    }

    try {
      final userData = {
        'name': _nameController.text.trim(),
        'email': '${_nameController.text.toLowerCase()}@example.com',
        'phone': '123-456-7890',
      };

      await _dio.post('/users', data: userData);

      _nameController.clear();
      _showSnackBar('Usuário adicionado com sucesso!', Colors.green);

      // Se online, recarrega a lista
      if (_isConnected) {
        await _loadUsers();
      }
    } catch (e) {
      if (e.toString().contains('enfileirada')) {
        _showSnackBar('Usuário será sincronizado quando conectar', Colors.blue);
        _nameController.clear();
      } else {
        _showSnackBar('Erro ao adicionar usuário: $e', Colors.red);
      }
    }
  }

  Future<void> _deleteUser(int userId) async {
    try {
      await _dio.delete('/users/$userId');
      _showSnackBar('Usuário removido!', Colors.green);

      if (_isConnected) {
        await _loadUsers();
      }
    } catch (e) {
      if (e.toString().contains('enfileirada')) {
        _showSnackBar('Remoção será sincronizada quando conectar', Colors.blue);
      } else {
        _showSnackBar('Erro ao remover usuário: $e', Colors.red);
      }
    }
  }

  void _updateQueuedRequests() {
    setState(() {
      _queuedRequests = Resync.instance.syncManager.getQueuedRequests();
    });
  }

  Future<void> _forceSync() async {
    await Resync.instance.syncManager.forceSync();
    _showSnackBar('Sincronização forçada', Colors.blue);
  }

  Future<void> _clearCache() async {
    await Resync.instance.cacheManager.clearAll();
    _showSnackBar('Cache limpo', Colors.blue);
    await _loadUsers();
  }

  @override
  void dispose() {
    _syncSubscription.cancel();
    _connectivitySubscription.cancel();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resync Example'),
        backgroundColor: _isConnected ? Colors.green : Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _forceSync,
            tooltip: 'Forçar sincronização',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearCache,
            tooltip: 'Limpar cache',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status de conectividade
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.wifi : Icons.wifi_off,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? 'Online' : 'Offline',
                  style: TextStyle(
                    color:
                        _isConnected
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_queuedRequests.isNotEmpty)
                  Chip(
                    label: Text('${_queuedRequests.length} na fila'),
                    backgroundColor: Colors.orange.shade100,
                  ),
              ],
            ),
          ),

          // Formulário para adicionar usuário
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do usuário',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addUser(),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _addUser,
                  child: const Text('Adicionar'),
                ),
              ],
            ),
          ),

          // Lista de usuários
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(user['name'][0].toString().toUpperCase()),
                    ),
                    title: Text(user['name']),
                    subtitle: Text(user['email']),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteUser(user['id']),
                    ),
                  );
                },
              ),
            ),
          ),

          // Informações da fila de sincronização
          if (_queuedRequests.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.orange.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fila de Sincronização (${_queuedRequests.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._queuedRequests
                      .take(3)
                      .map(
                        (request) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${request.method.value} ${request.url} - ${request.status.name}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                  if (_queuedRequests.length > 3)
                    Text(
                      '... e mais ${_queuedRequests.length - 3} requisições',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
