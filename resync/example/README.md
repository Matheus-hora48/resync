# Resync

Sistema robusto de cache e sincronização offline de requisições HTTP para apps Flutter.

## 🚀 Funcionalidades

- **Cache automático** de requisições GET com TTL configurável
- **Fila de sincronização** para POST/PUT/PATCH/DELETE quando offline
- **Detecção de conectividade** automática
- **Retry com backoff exponencial**
- **Headers dinâmicos** para reenvio (ex: tokens atualizados)
- **Observabilidade** completa com streams de eventos
- **Compatibilidade** com Dio

## 📦 Instalação

```yaml
dependencies:
  resync: ^0.0.1
```

## 🛠 Configuração

### 1. Inicialização

```dart
import 'package:resync/resync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Resync
  await Resync.instance.initialize(
    defaultCacheTtl: Duration(hours: 2),
    maxRetries: 3,
    initialRetryDelay: Duration(seconds: 1),
    getAuthHeaders: () => {
      'Authorization': 'Bearer ${getCurrentToken()}',
    },
  );

  runApp(MyApp());
}
```

### 2. Configuração do Dio

```dart
import 'package:dio/dio.dart';
import 'package:resync/resync.dart';

final dio = Dio();

// Adiciona o interceptor Resync
dio.addResyncInterceptor(
  cacheManager: Resync.instance.cacheManager,
  syncManager: Resync.instance.syncManager,
  connectivityService: Resync.instance.connectivityService,
  defaultCacheTtl: Duration(hours: 1),
  cacheGetRequests: true,
  queueMutatingRequests: true,
);
```

## 💡 Uso

### Cache Automático (GET)

```dart
// Esta requisição será cacheada automaticamente
final response = await dio.get('/api/users');

// Se offline, retornará do cache
// Se online, fará a requisição e atualizará o cache
```

### Sincronização Offline (POST/PUT/PATCH/DELETE)

```dart
try {
  // Se online: executa normalmente
  // Se offline: adiciona à fila de sincronização
  await dio.post('/api/users', data: userData);
} catch (e) {
  if (e.message?.contains('enfileirada') == true) {
    // Requisição foi enfileirada para sincronização
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Dados salvos. Sincronizará quando conectar.')),
    );
  }
}
```

### Observando Eventos de Sincronização

```dart
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late StreamSubscription _syncSubscription;

  @override
  void initState() {
    super.initState();

    // Escuta eventos de sincronização
    _syncSubscription = Resync.instance.syncManager.eventStream.listen((event) {
      switch (event.type) {
        case SyncEventType.completed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ ${event.message}')),
          );
          break;
        case SyncEventType.failed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ ${event.message}')),
          );
          break;
        // ... outros eventos
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription.cancel();
    super.dispose();
  }
}
```

### Monitorando Status de Conectividade

```dart
StreamBuilder<bool>(
  stream: Resync.instance.connectivityService.connectionStream,
  builder: (context, snapshot) {
    final isConnected = snapshot.data ?? false;

    return Container(
      color: isConnected ? Colors.green : Colors.red,
      child: Text(isConnected ? 'Online' : 'Offline'),
    );
  },
);
```

### Verificando Fila de Sincronização

```dart
// Obtém requisições pendentes
final pendingRequests = Resync.instance.syncManager.getQueuedRequests();

// Força sincronização (útil para botão "Sincronizar agora")
await Resync.instance.syncManager.forceSync();

// Cancela uma requisição específica
await Resync.instance.syncManager.cancelRequest(requestId);
```

## 🎛 API Avançada

### Cache Manual

```dart
final cacheManager = Resync.instance.cacheManager;

// Armazena dados no cache
await cacheManager.put('user_profile', userData, ttl: Duration(minutes: 30));

// Recupera do cache
final cachedData = cacheManager.get('user_profile');

// Limpa cache expirado
await cacheManager.clearExpired();

// Estatísticas do cache
final stats = cacheManager.getStats();
print('Total: ${stats.totalItems}, Válidos: ${stats.validItems}');
```

### Políticas de Retry Customizadas

```dart
// Retry agressivo
await Resync.instance.initialize(
  maxRetries: 5,
  initialRetryDelay: Duration(milliseconds: 500),
);

// Retry conservativo
await Resync.instance.initialize(
  maxRetries: 2,
  initialRetryDelay: Duration(seconds: 5),
);
```

### Headers Dinâmicos

```dart
await Resync.instance.initialize(
  getAuthHeaders: () {
    final token = TokenManager.getCurrentToken();
    final userId = UserManager.getCurrentUserId();

    return {
      'Authorization': 'Bearer $token',
      'X-User-ID': userId,
      'X-App-Version': '1.0.0',
    };
  },
);
```

## 🧪 Testando

```dart
// Para testes, você pode simular offline
connectivityService.setOfflineForTesting(true);

// Ou forçar sincronização
await syncManager.forceSync();

// Verificar se requisição foi enfileirada
final queuedRequests = syncManager.getQueuedRequests();
expect(queuedRequests.length, 1);
```

## 🔧 Configurações Avançadas

### TTL por Requisição

```dart
// Cache por 5 minutos
await dio.get('/api/data', options: Options(
  headers: {'Cache-Control': 'max-age=300'}
));

// Não fazer cache
await dio.get('/api/real-time-data', options: Options(
  headers: {'Cache-Control': 'no-cache'}
));
```

### Prioridades na Fila

```dart
// Requisições críticas têm prioridade maior
final urgentRequest = SyncRequest(
  url: '/api/critical-data',
  method: HttpMethod.post,
  body: criticalData,
  priority: 10, // Maior prioridade
);

await syncManager.addToQueue(urgentRequest);
```

## 🚫 Limitações

- Arquivos grandes não são recomendados para sincronização offline
- FormData com arquivos armazena apenas metadados, não o conteúdo
- Cache é limitado pelo armazenamento do dispositivo

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para detalhes.
