@echo off
REM Script para servir la aplicación Flutter web localmente

echo 🚀 Starting local Flutter web server...

REM Check if build directory exists
if not exist "build\web" (
    echo 📦 Build directory not found. Building Flutter web app...
    flutter build web --release --base-href /
)

REM Start a simple HTTP server
where python >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo 🌐 Starting Python HTTP server on http://localhost:8000
    cd build\web && python -m http.server 8000
) else (
    where node >nul 2>nul
    if %ERRORLEVEL% EQU 0 (
        echo 📦 Installing http-server globally...
        npm install -g http-server
        echo 🌐 Starting Node.js HTTP server on http://localhost:8000
        cd build\web && npx http-server -p 8000
    ) else (
        echo ❌ No Python or Node.js found. Please install one of them to serve the app locally.
        echo 💡 Alternatively, you can use any static file server to serve the build\web directory.
        pause
    )
)
