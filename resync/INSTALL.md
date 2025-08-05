# Instalação do Resync

## 📋 Checklist de Instalação

### 1. Adicione a dependência

```yaml
dependencies:
  resync: ^0.0.1
  dio: ^5.4.0 # Se ainda não tiver
```

### 2. Execute flutter pub get

```bash
flutter pub get
```

### 3. Inicialize no main()

```dart
import 'package:resync/resync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Resync.instance.initialize();

  runApp(MyApp());
}
```

### 4. Configure o Dio

```dart
import 'package:dio/dio.dart';
import 'package:resync/resync.dart';

final dio = Dio();

dio.addResyncInterceptor(
  cacheManager: Resync.instance.cacheManager,
  syncManager: Resync.instance.syncManager,
  connectivityService: Resync.instance.connectivityService,
);
```

### 5. ✅ Pronto!

Agora suas requisições terão cache automático e sincronização offline!

## 🔧 Configuração Avançada (Opcional)

```dart
await Resync.instance.initialize(
  // Cache padrão por 2 horas
  defaultCacheTtl: Duration(hours: 2),

  // Máximo 5 tentativas de retry
  maxRetries: 5,

  // Delay inicial de 500ms
  initialRetryDelay: Duration(milliseconds: 500),

  // Headers dinâmicos (tokens, etc)
  getAuthHeaders: () => {
    'Authorization': 'Bearer ${getCurrentToken()}',
    'X-User-ID': getCurrentUserId(),
  },
);
```

## 📱 Permissões Android

Adicione no `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

## 🍎 Configuração iOS

Nenhuma configuração adicional necessária para iOS.

## 🧪 Verificação

Execute este código para testar:

```dart
// Teste de cache
final response = await dio.get('https://jsonplaceholder.typicode.com/users');
print('Cache funcionando: ${response.data.length} usuários');

// Teste de sincronização (simule offline)
try {
  await dio.post('https://jsonplaceholder.typicode.com/users',
                 data: {'name': 'Teste'});
} catch (e) {
  print('Sincronização funcionando: $e');
}
```

## 🆘 Problemas Comuns

### "MissingPluginException"

- Execute `flutter clean && flutter pub get`
- Restart completo do app

### "Hive not initialized"

- Certifique-se de chamar `Resync.instance.initialize()` antes de usar

### Cache não funciona

- Verifique se não há header `Cache-Control: no-cache`
- Confirme que a requisição é GET

### Sincronização não acontece

- Verifique conectividade de rede
- Confirme que a requisição é POST/PUT/PATCH/DELETE

## 📞 Suporte

- GitHub Issues: [repositório/issues](https://github.com/yourusername/resync/issues)
- Documentação: [README.md](../README.md)
- Exemplo completo: [example/](../example/)
