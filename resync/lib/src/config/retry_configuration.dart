import '../sync/retry_policy.dart';

/// Configurações avançadas de retry por endpoint ou método HTTP
class RetryConfiguration {
  final Map<String, RetryPolicy> _endpointPolicies = {};
  final Map<String, RetryPolicy> _methodPolicies = {};
  final RetryPolicy _defaultPolicy;

  RetryConfiguration({
    RetryPolicy? defaultPolicy,
    Map<String, RetryPolicy>? endpointPolicies,
    Map<String, RetryPolicy>? methodPolicies,
  }) : _defaultPolicy = defaultPolicy ?? HttpRetryPolicy() {
    if (endpointPolicies != null) {
      _endpointPolicies.addAll(endpointPolicies);
    }
    if (methodPolicies != null) {
      _methodPolicies.addAll(methodPolicies);
    }
  }

  /// Define política de retry para um endpoint específico
  void setEndpointPolicy(String endpoint, RetryPolicy policy) {
    _endpointPolicies[endpoint] = policy;
  }

  /// Define política de retry para um método HTTP específico
  void setMethodPolicy(String method, RetryPolicy policy) {
    _methodPolicies[method.toUpperCase()] = policy;
  }

  /// Remove política de retry para um endpoint
  void removeEndpointPolicy(String endpoint) {
    _endpointPolicies.remove(endpoint);
  }

  /// Remove política de retry para um método HTTP
  void removeMethodPolicy(String method) {
    _methodPolicies.remove(method.toUpperCase());
  }

  /// Obtém a política de retry apropriada para uma requisição
  /// Prioridade: endpoint específico > método HTTP > política padrão
  RetryPolicy getPolicyForRequest(String url, String method) {
    // 1. Verifica se há política específica para o endpoint
    for (final endpoint in _endpointPolicies.keys) {
      if (url.contains(endpoint)) {
        return _endpointPolicies[endpoint]!;
      }
    }

    // 2. Verifica se há política específica para o método HTTP
    final methodPolicy = _methodPolicies[method.toUpperCase()];
    if (methodPolicy != null) {
      return methodPolicy;
    }

    // 3. Retorna política padrão
    return _defaultPolicy;
  }

  /// Obtém todas as políticas de endpoint configuradas
  Map<String, RetryPolicy> get endpointPolicies =>
      Map.unmodifiable(_endpointPolicies);

  /// Obtém todas as políticas de método configuradas
  Map<String, RetryPolicy> get methodPolicies =>
      Map.unmodifiable(_methodPolicies);

  /// Obtém a política padrão
  RetryPolicy get defaultPolicy => _defaultPolicy;

  /// Limpa todas as configurações personalizadas
  void clear() {
    _endpointPolicies.clear();
    _methodPolicies.clear();
  }

  /// Converte para Map para serialização
  Map<String, dynamic> toMap() {
    return {
      'endpointPolicies': _endpointPolicies.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'methodPolicies': _methodPolicies.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'defaultPolicy': _defaultPolicy.toMap(),
    };
  }

  /// Cria instância a partir de Map
  factory RetryConfiguration.fromMap(Map<String, dynamic> map) {
    final endpointPolicies = <String, RetryPolicy>{};
    final methodPolicies = <String, RetryPolicy>{};

    if (map['endpointPolicies'] != null) {
      final endpointMap = map['endpointPolicies'] as Map<String, dynamic>;
      for (final entry in endpointMap.entries) {
        endpointPolicies[entry.key] = RetryPolicy.fromMap(entry.value);
      }
    }

    if (map['methodPolicies'] != null) {
      final methodMap = map['methodPolicies'] as Map<String, dynamic>;
      for (final entry in methodMap.entries) {
        methodPolicies[entry.key] = RetryPolicy.fromMap(entry.value);
      }
    }

    final defaultPolicy =
        map['defaultPolicy'] != null
            ? RetryPolicy.fromMap(map['defaultPolicy'])
            : HttpRetryPolicy();

    return RetryConfiguration(
      defaultPolicy: defaultPolicy,
      endpointPolicies: endpointPolicies,
      methodPolicies: methodPolicies,
    );
  }

  @override
  String toString() {
    return 'RetryConfiguration('
        'endpoints: ${_endpointPolicies.length}, '
        'methods: ${_methodPolicies.length}, '
        'default: $_defaultPolicy)';
  }
}

/// Builder para facilitar a criação de configurações de retry
class RetryConfigurationBuilder {
  final Map<String, RetryPolicy> _endpointPolicies = {};
  final Map<String, RetryPolicy> _methodPolicies = {};
  RetryPolicy? _defaultPolicy;

  /// Define política padrão
  RetryConfigurationBuilder setDefault(RetryPolicy policy) {
    _defaultPolicy = policy;
    return this;
  }

  /// Adiciona política para endpoint crítico (5 tentativas, delay alto)
  RetryConfigurationBuilder criticalEndpoint(String endpoint) {
    _endpointPolicies[endpoint] = HttpRetryPolicy(
      maxRetries: 5,
      initialDelay: Duration(seconds: 2),
      strategy: RetryStrategy.exponential,
    );
    return this;
  }

  /// Adiciona política para endpoint de analytics (2 tentativas, delay baixo)
  RetryConfigurationBuilder analyticsEndpoint(String endpoint) {
    _endpointPolicies[endpoint] = HttpRetryPolicy(
      maxRetries: 2,
      initialDelay: Duration(milliseconds: 500),
      strategy: RetryStrategy.linear,
    );
    return this;
  }

  /// Adiciona política personalizada para endpoint
  RetryConfigurationBuilder endpoint(String endpoint, RetryPolicy policy) {
    _endpointPolicies[endpoint] = policy;
    return this;
  }

  /// Adiciona política para método HTTP específico
  RetryConfigurationBuilder method(String method, RetryPolicy policy) {
    _methodPolicies[method.toUpperCase()] = policy;
    return this;
  }

  /// Configuração para POSTs críticos (mais tentativas)
  RetryConfigurationBuilder criticalPosts() {
    _methodPolicies['POST'] = HttpRetryPolicy(
      maxRetries: 5,
      initialDelay: Duration(seconds: 1),
      strategy: RetryStrategy.exponential,
    );
    return this;
  }

  /// Configuração para GETs rápidos (menos tentativas)
  RetryConfigurationBuilder fastGets() {
    _methodPolicies['GET'] = HttpRetryPolicy(
      maxRetries: 2,
      initialDelay: Duration(milliseconds: 300),
      strategy: RetryStrategy.linear,
    );
    return this;
  }

  /// Constrói a configuração final
  RetryConfiguration build() {
    return RetryConfiguration(
      defaultPolicy: _defaultPolicy,
      endpointPolicies: _endpointPolicies,
      methodPolicies: _methodPolicies,
    );
  }
}

/// Configurações pré-definidas comuns
class RetryConfigurationPresets {
  /// Configuração para apps de e-commerce
  static RetryConfiguration ecommerce() {
    return RetryConfigurationBuilder()
        .setDefault(HttpRetryPolicy(maxRetries: 3))
        .criticalEndpoint('/api/payment')
        .criticalEndpoint('/api/order')
        .analyticsEndpoint('/api/analytics')
        .analyticsEndpoint('/api/tracking')
        .criticalPosts()
        .build();
  }

  /// Configuração para apps de redes sociais
  static RetryConfiguration socialMedia() {
    return RetryConfigurationBuilder()
        .setDefault(HttpRetryPolicy(maxRetries: 2))
        .criticalEndpoint('/api/auth')
        .criticalEndpoint('/api/profile')
        .analyticsEndpoint('/api/metrics')
        .endpoint('/api/posts', HttpRetryPolicy(maxRetries: 4))
        .fastGets()
        .build();
  }

  /// Configuração para apps corporativos
  static RetryConfiguration enterprise() {
    return RetryConfigurationBuilder()
        .setDefault(
          HttpRetryPolicy(
            maxRetries: 5,
            initialDelay: Duration(seconds: 2),
            strategy: RetryStrategy.exponential,
          ),
        )
        .criticalEndpoint('/api/core')
        .criticalEndpoint('/api/auth')
        .criticalEndpoint('/api/sync')
        .method('DELETE', HttpRetryPolicy(maxRetries: 3))
        .build();
  }

  /// Configuração básica/padrão
  static RetryConfiguration basic() {
    return RetryConfigurationBuilder().setDefault(HttpRetryPolicy()).build();
  }
}
