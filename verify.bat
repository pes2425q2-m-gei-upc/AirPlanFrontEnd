@echo off
REM Script de verificación antes del deployment

echo 🔍 Verificando configuración para deployment...

REM Verificar que Flutter esté instalado
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter no está instalado
    exit /b 1
)

REM Verificar versión de Flutter y Dart
echo 📋 Versiones actuales:
flutter --version

REM Verificar que el proyecto se pueda compilar
echo 🛠️  Verificando que el proyecto compile...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Error al obtener dependencias
    exit /b 1
)

REM Ejecutar análisis estático
echo 🔎 Ejecutando análisis estático...
flutter analyze
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️  Hay warnings en el análisis estático
)

REM Ejecutar tests
echo 🧪 Ejecutando tests...
flutter test
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Los tests fallaron
    exit /b 1
)

REM Verificar que la build web funcione
echo 🌐 Verificando build web...
flutter build web --release --base-href /
if %ERRORLEVEL% NEQ 0 (
    echo ❌ La build web falló
    exit /b 1
)

echo ✅ Todas las verificaciones pasaron!
echo 🚀 El proyecto está listo para deployment
pause
