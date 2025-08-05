# Resync

Sistema robusto de cache e sincronização offline de requisições HTTP para apps Flutter, funcionando com Dio e HTTP package.

## ✨ Funcionalidades

### 🚀 Core Features

- 🗄️ **Cache automático** de requisições GET com TTL configurável
- 📋 **Fila de sincronização** para POST/PUT/PATCH/DELETE quando offline
- 🌐 **Detecção de conectividade** automática
- 🔄 **Retry com backoff exponencial**
- 🔑 **Headers dinâmicos** para reenvio (ex: tokens atualizados)
- 📊 **Observabilidade** completa com streams de eventos
- 🛠️ **Compatibilidade** total com Dio e HTTP package

### 🔥 Premium Features

- 🎛️ **Debug Panel Widget** - Dashboard visual para desenvolvedores
- 📤 **Upload Manager** - Sistema robusto para upload de arquivos offline
- 📈 **Estatísticas em tempo real** - Métricas de cache, sync e uploads
- 🎯 **Priorização de uploads** - Sistema de filas com prioridade

## 📦 Instalação

```yaml
dependencies:
  resync: ^0.0.1
```

## 🚀 Uso Rápido

### Com Dio

```dart
// 1. Inicialize o Resync
await Resync.instance.initialize();

// 2. Configure seu Dio
final dio = Dio();
dio.addResyncInterceptor(
  cacheManager: Resync.instance.cacheManager,
  syncManager: Resync.instance.syncManager,
  connectivityService: Resync.instance.connectivityService,
);

// 3. Use normalmente - cache e sincronização são automáticos!
final response = await dio.get('/api/users'); // Cacheado automaticamente
await dio.post('/api/users', data: userData); // Enfileirado se offline
```

### Com HTTP Package

```dart
// 1. Inicialize o Resync
await Resync.instance.initialize();

// 2. Configure seu HTTP Client
final httpClient = ResyncHttpClient(
  cacheManager: Resync.instance.cacheManager,
  syncManager: Resync.instance.syncManager,
  connectivityService: Resync.instance.connectivityService,
);

// 3. Use como http.Client normal
final response = await httpClient.get(Uri.parse('/api/users'));
await httpClient.post(Uri.parse('/api/users'), body: json.encode(userData));
```

## 🎛️ Debug Panel (Premium Feature)

Widget visual para acompanhar o status do Resync em tempo real:

```dart
class MyDebugScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Resync Debug')),
      body: Column(
        children: [
          // Dashboard visual com estatísticas em tempo real
          ResyncDebugPanel(
            height: 300,
            showCacheStats: true,
            showSyncQueue: true,
            showConnectivity: true,
          ),
          // Resto da sua UI...
        ],
      ),
    );
  }
}
```

## 📤 Upload Manager (Premium Feature)

Sistema robusto para upload de arquivos offline com retry automático:

```dart
class FileUploadExample extends StatelessWidget {
  Future<void> uploadFile() async {
    // Upload com fila offline automática
    final uploadId = await Resync.instance.uploadManager.queueUpload(
      url: 'https://api.example.com/upload',
      filePath: '/path/to/file.jpg',
      fileName: 'profile_picture.jpg',
      formData: {
        'description': 'Foto do perfil',
        'userId': '123',
      },
      priority: 1, // Prioridade alta
    );

    print('Upload enfileirado: $uploadId');

    // Cancelar upload se necessário
    // await Resync.instance.uploadManager.cancelUpload(uploadId);
  }

  Future<void> checkUploadStats() async {
    final stats = await Resync.instance.uploadManager.getUploadStats();
    print('Uploads pendentes: ${stats['queued']}');
    print('Uploads em progresso: ${stats['uploading']}');
    print('Uploads concluídos: ${stats['completed']}');
  }
}
  cacheManager: Resync.instance.cacheManager,
  syncManager: Resync.instance.syncManager,
  connectivityService: Resync.instance.connectivityService,
);

// 3. Use normalmente!
final response = await httpClient.get(Uri.parse('/api/users')); // Cacheado
await httpClient.post(Uri.parse('/api/users'), body: json.encode(userData)); // Enfileirado se offline
```

## 📚 Documentação Completa

Veja o [exemplo completo](example/) para uso detalhado com interface Flutter.

## 🧪 Como Funciona

### Cache Automático (GET)

- ✅ Requisições GET são cacheadas automaticamente
- ✅ Se offline, retorna do cache local
- ✅ TTL configurável por requisição ou global
- ✅ Headers `Cache-Control` são respeitados

### Sincronização Offline (POST/PUT/PATCH/DELETE)

- ✅ Requisições que falham são enfileiradas
- ✅ Reenvia automaticamente quando conecta
- ✅ Retry com backoff exponencial
- ✅ Headers atualizados no reenvio (tokens, etc)

### Observabilidade

- ✅ Stream de eventos de sincronização
- ✅ Stream de status de conectividade
- ✅ Estatísticas de cache e fila
- ✅ Logs detalhados em debug

## 🛠️ Configuração Avançada

```dart
await Resync.instance.initialize(
  defaultCacheTtl: Duration(hours: 2),
  maxRetries: 5,
  initialRetryDelay: Duration(seconds: 2),
  getAuthHeaders: () => {
    'Authorization': 'Bearer ${getCurrentToken()}',
    'X-User-ID': getCurrentUserId(),
  },
);
```

## 📊 Monitoramento

```dart
// Escuta eventos de sincronização
Resync.instance.syncManager.eventStream.listen((event) {
  print('${event.type}: ${event.message}');
});

// Monitora conectividade
Resync.instance.connectivityService.connectionStream.listen((connected) {
  print('Status: ${connected ? "Online" : "Offline"}');
});
```

## 🎯 Casos de Uso

- 📱 Apps que precisam funcionar offline
- 🏪 E-commerce com carrinho offline
- 📝 Formulários que não podem perder dados
- 🔄 Sincronização de dados em background
- 🚀 Melhoria de performance com cache

## 🤝 Contribuindo

Contribuições são bem-vindas! Veja o [roadmap](docs/roadmap.md) para funcionalidades planejadas.

## 📄 Licença

MIT License - veja [LICENSE](LICENSE) para detalhes.
