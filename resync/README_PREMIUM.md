# Resync - Premium Offline Sync Package 🚀

[![pub package](https://img.shields.io/pub/v/resync.svg)](https://pub.dev/packages/resync)
[![popularity](https://badges.bar/resync/popularity)](https://pub.dev/packages/resync/score)
[![likes](https://badges.bar/resync/likes)](https://pub.dev/packages/resync/score)
[![pub points](https://badges.bar/resync/pub%20points)](https://pub.dev/packages/resync/score)

**O sistema mais avançado de cache e sincronização offline para Flutter.**

Resync é um package premium que oferece cache automático, sincronização offline robusta e funcionalidades avançadas para apps Flutter profissionais.

---

## ✨ Funcionalidades Premium

### 🎛️ **Debug Panel Widget**

Interface visual em tempo real para monitorar operações do Resync:

- Dashboard com estatísticas ao vivo
- Monitor de cache hits/misses
- Visualização da fila de sincronização
- Status de conectividade em tempo real

### 📤 **Upload Manager**

Sistema enterprise para uploads offline:

- Queue com sistema de prioridades
- Progress tracking persistente
- Compressão automática de imagens
- Retry inteligente com backoff
- Suporte completo a MultipartFile

### ⚙️ **Advanced Retry Configuration**

Configurações granulares de retry:

- Políticas por endpoint específico
- Configurações por método HTTP
- Presets para diferentes tipos de app
- Builder pattern para flexibilidade

### 🖼️ **Image Compression**

Otimização automática de imagens:

- Compressão com qualidade configurável
- Redimensionamento inteligente
- Batch processing
- Cálculo automático de economia de espaço

### 📝 **Structured Logging**

Sistema de logs profissional:

- Níveis configuráveis (debug, info, warning, error, critical)
- Metadata estruturado
- Export para JSON
- Estatísticas e filtros

---

## 🚀 Instalação

```yaml
dependencies:
  resync: ^0.2.0

  # Dependências opcionais para funcionalidades específicas
  dio: ^5.0.0 # Para usar com Dio
```

```bash
flutter pub get
```

---

## 📖 Uso Básico

### Inicialização

```dart
import 'package:resync/resync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuração básica
  await Resync.instance.initialize(
    defaultCacheTtl: Duration(minutes: 30),
    maxRetries: 3,
  );

  runApp(MyApp());
}
```

### Com Dio

```dart
import 'package:dio/dio.dart';
import 'package:resync/resync.dart';

final dio = Dio();
dio.interceptors.add(ResyncDioInterceptor());

// Suas requisições funcionam normalmente
// Cache automático para GET, offline sync para POST/PUT/PATCH/DELETE
final response = await dio.get('/api/users');
```

### Com HTTP

```dart
import 'package:resync/resync.dart';

final client = ResyncHttpClient();

// Cache automático e sync offline transparente
final response = await client.get(Uri.parse('https://api.exemplo.com/users'));
```

---

## 🎛️ Debug Panel Premium

Adicione o widget visual para monitorar operações em tempo real:

```dart
import 'package:resync/resync.dart';

class MyDebugPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Resync Debug')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: ResyncDebugPanel(
          height: 400,
          backgroundColor: Colors.grey[100],
          showCacheStats: true,
          showSyncQueue: true,
          showConnectivity: true,
        ),
      ),
    );
  }
}
```

**Funcionalidades do Debug Panel:**

- 📊 Estatísticas de cache em tempo real
- 🔄 Visualização da fila de sincronização
- 🌐 Status de conectividade
- ⚡ Métricas de performance
- 📱 Interface responsiva e customizável

---

## 📤 Upload Manager

Sistema robusto para uploads offline com progress tracking:

```dart
import 'package:resync/resync.dart';

class UploadService {
  Future<void> uploadProfilePicture(String imagePath) async {
    try {
      final uploadId = await Resync.instance.uploadManager.queueUpload(
        url: 'https://api.exemplo.com/upload/profile',
        filePath: imagePath,
        fileName: 'profile_picture.jpg',
        formData: {
          'userId': '123',
          'type': 'profile',
        },
        priority: 2, // Alta prioridade
        compressImages: true, // Compressão automática
        onProgress: (progress) {
          print('Upload progress: ${(progress * 100).toInt()}%');
        },
      );

      print('Upload enfileirado com ID: $uploadId');
    } catch (e) {
      print('Erro no upload: $e');
    }
  }

  // Monitorar estatísticas de upload
  Future<void> checkUploadStats() async {
    final stats = await Resync.instance.uploadManager.getUploadStats();
    print('Total uploads: ${stats['total']}');
    print('Na fila: ${stats['queued']}');
    print('Enviando: ${stats['uploading']}');
    print('Concluídos: ${stats['completed']}');
    print('Falharam: ${stats['failed']}');
  }
}
```

**Funcionalidades do Upload Manager:**

- 🚀 Queue com sistema de prioridades
- 📊 Progress tracking persistente
- 🔄 Retry automático com backoff exponencial
- 🖼️ Compressão automática de imagens
- ❌ Cancelamento individual de uploads
- 📱 Suporte completo a FormData e MultipartFile

---

## ⚙️ Advanced Retry Configuration

Configure políticas de retry granulares por endpoint ou método:

```dart
import 'package:resync/resync.dart';

void main() async {
  // Configuração avançada de retry
  final retryConfig = RetryConfigurationBuilder()
    // Endpoints críticos: mais tentativas, delay maior
    .setEndpointConfig('/api/payment', RetryPolicy.critical())
    .setEndpointConfig('/api/order', RetryPolicy.critical())

    // Analytics: retry rápido, poucas tentativas
    .setEndpointConfig('/api/analytics', RetryPolicy.fast())

    // Métodos POST sempre críticos
    .setMethodConfig(HttpMethod.post, RetryPolicy.critical())

    // Configuração padrão
    .setDefaultPolicy(RetryPolicy.standard())
    .build();

  await Resync.instance.initialize(
    retryConfiguration: retryConfig,
  );
}

// Ou use presets pré-configurados
final ecommerceConfig = RetryConfigurationPresets.ecommerce();
final socialConfig = RetryConfigurationPresets.socialMedia();
final enterpriseConfig = RetryConfigurationPresets.enterprise();
```

**Presets Disponíveis:**

- 🛒 **E-commerce**: Pagamentos críticos, analytics rápidos
- 📱 **Social Media**: Posts importantes, métricas básicas
- 🏢 **Enterprise**: Máxima confiabilidade, logs detalhados
- ⚡ **Basic**: Configuração padrão simples

---

## 🖼️ Image Compression

Otimização automática de imagens antes do upload:

```dart
import 'package:resync/resync.dart';

class ImageService {
  Future<void> compressImages() async {
    // Compressão individual
    final compressedFile = await ImageCompressor.compressImage(
      '/path/to/large_image.jpg',
      quality: 0.8,
      maxWidth: 1920,
      maxHeight: 1080,
    );

    print('Tamanho original: ${await _getFileSize('/path/to/large_image.jpg')}');
    print('Tamanho comprimido: ${await compressedFile.length()}');

    // Compressão em lote
    final imagePaths = [
      '/path/to/image1.jpg',
      '/path/to/image2.png',
      '/path/to/image3.jpg',
    ];

    final compressedFiles = await ImageCompressor.compressBatch(
      imagePaths,
      quality: 0.7,
      maxWidth: 1080,
      maxHeight: 1080,
    );

    print('${compressedFiles.length} images compressed');
  }

  Future<String> _getFileSize(String path) async {
    final file = File(path);
    final bytes = await file.length();
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}
```

**Funcionalidades de Compressão:**

- 🎯 Qualidade configurável (0.1 a 1.0)
- 📐 Redimensionamento inteligente
- 📦 Batch processing para múltiplas imagens
- 💾 Cálculo automático de economia de espaço
- 🖼️ Suporte a JPEG, PNG, WebP

---

## 📝 Structured Logging

Sistema de logs profissional com níveis configuráveis:

```dart
import 'package:resync/resync.dart';

class MyService {
  void performCriticalOperation() {
    try {
      // Log com metadata estruturado
      ResyncLogger.instance.info(
        'Starting critical operation',
        component: 'MyService',
        metadata: {
          'userId': '123',
          'operationType': 'critical',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Operação...

      ResyncLogger.instance.info(
        'Operation completed successfully',
        component: 'MyService',
        metadata: {'duration': '1.2s', 'result': 'success'},
      );

    } catch (e, stackTrace) {
      ResyncLogger.instance.error(
        'Critical operation failed',
        component: 'MyService',
        error: e,
        stackTrace: stackTrace,
        metadata: {'attemptNumber': 1},
      );
    }
  }

  // Configurar logger para desenvolvimento
  void setupDevelopmentLogging() {
    ResyncLogger.configureForDevelopment();
  }

  // Exportar logs para análise
  Future<void> exportLogs() async {
    await ResyncLogger.instance.exportLogs('/path/to/logs.json');
  }

  // Obter estatísticas de logs
  void checkLogStats() {
    final stats = ResyncLogger.instance.getLogStats();
    print('Debug logs: ${stats['debug']}');
    print('Info logs: ${stats['info']}');
    print('Warning logs: ${stats['warning']}');
    print('Error logs: ${stats['error']}');
    print('Critical logs: ${stats['critical']}');
  }
}
```

**Funcionalidades do Logger:**

- 📊 5 níveis configuráveis (debug, info, warning, error, critical)
- 🏗️ Metadata estruturado para contexto
- 📄 Export para JSON com filtros
- 📈 Estatísticas automáticas
- 💾 Persistência local opcional
- 🎯 Configuração por ambiente

---

## 🔧 Configuração Avançada

### Headers Dinâmicos

```dart
await Resync.instance.initialize(
  getAuthHeaders: () => {
    'Authorization': 'Bearer ${TokenManager.getCurrentToken()}',
    'X-App-Version': '2.0.0',
    'X-Platform': Platform.isIOS ? 'ios' : 'android',
  },
);
```

### Configuração Completa

```dart
import 'package:resync/resync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuração premium completa
  final retryConfig = RetryConfigurationPresets.ecommerce();

  await Resync.instance.initialize(
    // Cache
    defaultCacheTtl: Duration(minutes: 30),

    // Retry
    maxRetries: 5,
    retryConfiguration: retryConfig,

    // Headers dinâmicos
    getAuthHeaders: () => {
      'Authorization': 'Bearer ${_getCurrentToken()}',
      'X-App-Version': '2.0.0',
    },

    // Logging
    enableLogging: true,
  );

  // Configurar logger para produção
  ResyncLogger.configureForProduction();

  runApp(MyApp());
}

String _getCurrentToken() {
  // Sua lógica de token aqui
  return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
}
```

---

## 📊 Monitoramento e Observabilidade

### Stream de Eventos

```dart
import 'package:resync/resync.dart';

class SyncStatusWidget extends StatefulWidget {
  @override
  _SyncStatusWidgetState createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  StreamSubscription<SyncStatus>? _subscription;
  String _lastSyncMessage = 'Aguardando sincronização...';

  @override
  void initState() {
    super.initState();

    // Escutar eventos de sincronização
    _subscription = Resync.instance.syncManager.syncStatusStream.listen(
      (status) {
        setState(() {
          switch (status.type) {
            case SyncStatusType.syncStarted:
              _lastSyncMessage = 'Sincronizando ${status.request?.url}...';
              break;
            case SyncStatusType.syncCompleted:
              _lastSyncMessage = 'Sincronização concluída!';
              break;
            case SyncStatusType.syncFailed:
              _lastSyncMessage = 'Erro na sincronização: ${status.error}';
              break;
            case SyncStatusType.queueEmpty:
              _lastSyncMessage = 'Todas as requisições sincronizadas';
              break;
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Text(_lastSyncMessage),
    );
  }
}
```

### Métricas de Performance

```dart
class PerformanceMonitor {
  static void trackCachePerformance() {
    // Estatísticas de cache
    final cacheStats = Resync.instance.cacheManager.getStats();
    print('Cache hits: ${cacheStats.hits}');
    print('Cache misses: ${cacheStats.misses}');
    print('Hit rate: ${cacheStats.hitRate.toStringAsFixed(2)}%');
  }

  static void trackSyncQueue() {
    // Status da fila de sincronização
    final queueSize = Resync.instance.syncManager.getQueueSize();
    print('Requests pendentes: $queueSize');
  }

  static void trackUploadPerformance() async {
    // Estatísticas de upload
    final uploadStats = await Resync.instance.uploadManager.getUploadStats();
    print('Upload success rate: ${uploadStats['completed'] / uploadStats['total'] * 100}%');
  }
}
```

---

## 🧪 Testes

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:resync/resync.dart';

void main() {
  group('Resync Tests', () {
    setUp(() async {
      await Resync.instance.initialize();
    });

    test('should cache GET requests', () async {
      // Seu teste aqui
    });

    test('should queue failed requests for sync', () async {
      // Seu teste aqui
    });

    test('should compress images correctly', () async {
      // Teste de compressão
    });
  });
}
```

---

## 📚 Exemplos Completos

Confira os exemplos na pasta `/example`:

- **Basic Usage**: Uso básico com Dio e HTTP
- **Premium Features Demo**: Demonstração de todas as funcionalidades premium
- **E-commerce App**: Exemplo real de app e-commerce
- **Social Media App**: Exemplo de app de redes sociais

---

## 🆚 Comparação com Outras Soluções

| Funcionalidade        | Resync | Dio Cache | HTTP Overrides | Hive   |
| --------------------- | ------ | --------- | -------------- | ------ |
| ✅ Cache automático   | ✅     | ✅        | ❌             | Manual |
| ✅ Sync offline       | ✅     | ❌        | ❌             | Manual |
| ✅ Debug visual       | ✅     | ❌        | ❌             | ❌     |
| ✅ Upload manager     | ✅     | ❌        | ❌             | ❌     |
| ✅ Retry avançado     | ✅     | Básico    | ❌             | ❌     |
| ✅ Image compression  | ✅     | ❌        | ❌             | ❌     |
| ✅ Structured logging | ✅     | ❌        | ❌             | ❌     |
| 🎯 Zero config        | ✅     | ❌        | ❌             | ❌     |

---

## 🏗️ Arquitetura

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Flutter App   │ -> │  Resync Package  │ -> │   Local Storage │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │   Remote API     │
                       └──────────────────┘
```

**Componentes Principais:**

- 🎛️ **ResyncDebugPanel**: Widget visual para monitoramento
- 📤 **UploadManager**: Sistema enterprise de uploads
- ⚙️ **RetryConfiguration**: Configurações granulares de retry
- 🖼️ **ImageCompressor**: Otimização automática de imagens
- 📝 **ResyncLogger**: Sistema de logs estruturados
- 🔄 **SyncManager**: Gerenciador de sincronização offline
- 💾 **CacheManager**: Cache inteligente com TTL
- 🌐 **ConnectivityService**: Detecção de conectividade

---

## 🛠️ Desenvolvimento

```bash
# Clonar o repositório
git clone https://github.com/usuario/resync.git

# Instalar dependências
flutter pub get

# Executar testes
flutter test

# Gerar coverage
flutter test --coverage

# Executar exemplo
cd example && flutter run
```

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor:

1. Fork o projeto
2. Crie sua feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

---

## 📄 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

---

## 🙋‍♂️ Suporte

- 📧 **Email**: suporte@resync.dev
- 🐛 **Issues**: [GitHub Issues](https://github.com/usuario/resync/issues)
- 💬 **Discussões**: [GitHub Discussions](https://github.com/usuario/resync/discussions)
- 📚 **Documentação**: [resync.dev](https://resync.dev)

---

## 🎯 Roadmap

### ✅ v0.2.0 - Premium Features (Atual)

- [x] Debug Panel Widget
- [x] Upload Manager
- [x] Advanced Retry Configuration
- [x] Image Compression
- [x] Structured Logging

### 🚧 v0.3.0 - Analytics & Background Sync

- [ ] Analytics Integration
- [ ] Background Sync Service
- [ ] Memory Management
- [ ] Network Optimization

### 📅 v1.0.0 - Enterprise Ready

- [ ] Multi-tenant Support
- [ ] Advanced Security
- [ ] Cross-Platform Support
- [ ] Cloud Integration

---

**Feito com ❤️ pela comunidade Flutter**

[![GitHub stars](https://img.shields.io/github/stars/usuario/resync.svg?style=social&label=Star)](https://github.com/usuario/resync)
[![Twitter Follow](https://img.shields.io/twitter/follow/resyncdev?style=social)](https://twitter.com/resyncdev)
