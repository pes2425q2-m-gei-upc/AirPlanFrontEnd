#!/bin/bash
# Script de verificación antes del deployment

echo "🔍 Verificando configuración para deployment..."

# Verificar que Flutter esté instalado
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter no está instalado"
    exit 1
fi

# Verificar versión de Flutter y Dart
echo "📋 Versiones actuales:"
flutter --version

# Verificar que el proyecto se pueda compilar
echo "🛠️  Verificando que el proyecto compile..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "❌ Error al obtener dependencias"
    exit 1
fi

# Ejecutar análisis estático
echo "🔎 Ejecutando análisis estático..."
flutter analyze
if [ $? -ne 0 ]; then
    echo "⚠️  Hay warnings en el análisis estático"
fi

# Ejecutar tests
echo "🧪 Ejecutando tests..."
flutter test
if [ $? -ne 0 ]; then
    echo "❌ Los tests fallaron"
    exit 1
fi

# Verificar que la build web funcione
echo "🌐 Verificando build web..."
flutter build web --release --base-href /
if [ $? -ne 0 ]; then
    echo "❌ La build web falló"
    exit 1
fi

echo "✅ Todas las verificaciones pasaron!"
echo "🚀 El proyecto está listo para deployment"
