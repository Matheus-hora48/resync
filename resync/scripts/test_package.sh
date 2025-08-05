#!/bin/bash

# Script para testar o package Resync de forma completa
echo "🚀 Iniciando testes completos do Resync Package"

# 1. Análise de código
echo "📊 1. Análise de código..."
flutter analyze

if [ $? -ne 0 ]; then
    echo "❌ Análise de código falhou"
    exit 1
fi

# 2. Testes unitários
echo "🧪 2. Executando testes unitários..."
flutter test

if [ $? -ne 0 ]; then
    echo "❌ Testes unitários falharam"
    exit 1
fi

# 3. Teste de build do exemplo
echo "📱 3. Testando build do exemplo..."
cd example
flutter build apk --debug

if [ $? -ne 0 ]; then
    echo "❌ Build do exemplo falhou"
    exit 1
fi

cd ..

# 4. Verificar estrutura do package
echo "📦 4. Verificando estrutura do package..."
flutter pub publish --dry-run

if [ $? -ne 0 ]; then
    echo "❌ Verificação de publicação falhou"
    exit 1
fi

echo "✅ Todos os testes passaram! Package está pronto."
echo ""
echo "🎯 Próximos passos para teste real:"
echo "   1. Criar app separado com 'flutter create test_real_app'"
echo "   2. Adicionar resync como dependência local"
echo "   3. Testar funcionalidades em app real"
echo "   4. Publicar no pub.dev quando estiver satisfeito"
