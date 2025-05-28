#!/bin/bash

# Script para servir la aplicación Flutter web localmente

echo "🚀 Starting local Flutter web server..."

# Check if build directory exists
if [ ! -d "build/web" ]; then
    echo "📦 Build directory not found. Building Flutter web app..."
    flutter build web --release --base-href /
fi

# Start a simple HTTP server
if command -v python3 &> /dev/null; then
    echo "🌐 Starting Python HTTP server on http://localhost:8000"
    cd build/web && python3 -m http.server 8000
elif command -v python &> /dev/null; then
    echo "🌐 Starting Python HTTP server on http://localhost:8000"
    cd build/web && python -m http.server 8000
elif command -v node &> /dev/null; then
    echo "📦 Installing http-server globally..."
    npm install -g http-server
    echo "🌐 Starting Node.js HTTP server on http://localhost:8000"
    cd build/web && npx http-server -p 8000
else
    echo "❌ No Python or Node.js found. Please install one of them to serve the app locally."
    echo "💡 Alternatively, you can use any static file server to serve the build/web directory."
fi
