#!/bin/bash

# Script para testar o package Resync - versão simplificada
echo "🚀 Iniciando testes essenciais do Resync Package"

# 1. Testes unitários (mais importante)
echo "🧪 1. Executando testes unitários..."
flutter test

if [ $? -ne 0 ]; then
    echo "❌ Testes unitários falharam"
    exit 1
fi

# 2. Verificar estrutura do package
echo "📦 2. Verificando estrutura do package..."
flutter pub publish --dry-run

if [ $? -ne 0 ]; then
    echo "❌ Verificação de publicação falhou"
    exit 1
fi

echo "✅ Testes principais passaram! Package está funcionando."
echo ""
echo "🎯 Para teste manual completo:"
echo "   cd example && flutter run -d chrome lib/real_test_app.dart"
echo ""
echo "📊 Para análise completa (com warnings):"
echo "   flutter analyze"
